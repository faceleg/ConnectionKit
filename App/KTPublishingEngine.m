//
//  KTExportEngine.m
//  Marvel
//
//  Created by Mike on 12/12/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTPublishingEngine.h"

#import "KTPage+Internal.h"
#import "KTDesign.h"
#import "KTSite.h"
#import "SVHTMLTextBlock.h"
#import "KTMaster.h"
#import "SVMediaGatheringHTMLContext.h"
#import "SVMediaGatheringPublishingContext.h"
#import "SVMediaRecord.h"
#import "SVMediaRepresentation.h"
#import "KTPage+Internal.h"
#import "SVPublishingHTMLContext.h"
#import "SVPublishingRecord.h"
#import "KTTranscriptController.h"

#import "KTMediaFileUpload.h"
#import "KTImageScalingURLProtocol.h"

#import "NSBundle+KTExtensions.h"
#import "NSString+KTExtensions.h"

#import "NSData+Karelia.h"
#import "NSDictionary+Karelia.h"
#import "NSError+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSThread+Karelia.h"
#import "NSURL+Karelia.h"

#import "KSSimpleURLConnection.h"
#import "KSPlugInWrapper.h"
#import "KSThreadProxy.h"

#import "Debug.h"
#import "Registration.h"

int kMaxNumberOfFreePublishedPages = 8;	// This is the constant value of how many pages max to publish when it's the free/lite/demo/unlicensed state.

NSString *KTPublishingEngineErrorDomain = @"KTPublishingEngineError";


@interface KTPublishingEngine ()

- (void)setRootTransferRecord:(CKTransferRecord *)rootRecord;

- (BOOL)shouldPublishToPath:(NSString *)path;
- (void)didQueueUpload:(CKTransferRecord *)record toDirectory:(CKTransferRecord *)parent;

@end


@interface KTPublishingEngine (SubclassSupportPrivate)

- (void)publishNonPageContent;

// Media
- (void)gatherMedia;

// Resources
- (void)addResourceFile:(NSURL *)resourceURL;

- (CKTransferRecord *)createDirectory:(NSString *)remotePath;
- (unsigned long)remoteFilePermissions;
- (unsigned long)remoteDirectoryPermissions;

@end


#pragma mark -


@implementation KTPublishingEngine

#pragma mark Init & Dealloc

/*  Subfolder can be either nil (there isn't one), or a path relative to the doc root. Exporting
 *  never uses a subfolder, but full-on publishing can.
 */
- (id)initWithSite:(KTSite *)site
  documentRootPath:(NSString *)docRoot
     subfolderPath:(NSString *)subfolder
{
	OBPRECONDITION(site);
    
    if (!docRoot) docRoot = @"";    // We need a string that can receive -stringByAppendingPathComponent: messages
    OBASSERT(docRoot);
    
    
    if (self = [super init])
	{
		_site = [site retain];
        
        _paths = [[NSMutableSet alloc] init];
        _uploadedMediaReps = [[NSMutableDictionary alloc] init];
        
        _graphicalTextBlocks = [[NSMutableDictionary alloc] init];
        
        _documentRootPath = [docRoot copy];
        _subfolderPath = [subfolder copy];
	}
	
	return self;
}

- (void)dealloc
{
    // The connection etc. should already have been shut down
    OBASSERT(!_connection);
    
    [_baseTransferRecord release];
    [_rootTransferRecord release];
    [_site release];
	[_documentRootPath release];
    [_subfolderPath release];
    
    [_paths release];
    
    [_graphicalTextBlocks release];
	
	[super dealloc];
}

#pragma mark Simple Accessors

- (KTSite *)site { return _site; }

- (NSString *)documentRootPath { return _documentRootPath; }

- (NSString *)subfolderPath { return _subfolderPath; }
    
/*  Combines doc root and subfolder to get the directory that all content goes into
 */
- (NSString *)baseRemotePath
{
    NSString *result = [[self documentRootPath] stringByAppendingPathComponent:[self subfolderPath]];
    return result;
}

#pragma mark Overall flow control

- (void)start
{
	if ([self status] != KTPublishingEngineStatusNotStarted) return;
    _status = KTPublishingEngineStatusGatheringMedia;
    
    [self main];
}

- (void)main
{
    // Setup connection and transfer records
    [self createConnection];
    [self setRootTransferRecord:[CKTransferRecord rootRecordWithPath:[[self documentRootPath] standardizedPOSIXPath]]];
    
    
    // Start by publishing the home page if setting up connection was successful
    if ([self status] <= KTPublishingEngineStatusUploading)
    {
        [self gatherMedia];
    
        
        // Publish pages properly
        _status = KTPublishingEngineStatusParsing;
        KTPage *home = [[self site] rootPage];
        [home publish:self recursively:YES];
        
        
        // Finish up
        [self publishNonPageContent];
    }
}

- (void)cancel
{
    // Mark self as finished
    if ([self status] > KTPublishingEngineStatusNotStarted && [self status] < KTPublishingEngineStatusFinished)
    {
        [self engineDidPublish:NO error:[NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil]];
    }
}

- (KTPublishingEngineStatus)status { return _status; }

#pragma mark Transfer Records

- (CKTransferRecord *)rootTransferRecord { return _rootTransferRecord; }

/*  Also has the side-effect of updating the base transfer record
 */
- (void)setRootTransferRecord:(CKTransferRecord *)rootRecord
{
    [rootRecord retain];
    [_rootTransferRecord release];
    _rootTransferRecord = rootRecord;
    
    // If there is a subfolder, create it. This also gives us a valid -baseTransferRecord
    [self willChangeValueForKey:@"baseTransferRecord"]; // Automatic KVO-notifications are used for rootTransferRecord
    [_baseTransferRecord release];
    _baseTransferRecord = (rootRecord) ? [[self createDirectory:[self baseRemotePath]] retain] : nil;
    [self didChangeValueForKey:@"baseTransferRecord"];
}

/*  The transfer record corresponding to -baseRemotePath. There is no decdicated setter method, use
 *  -setRootTransferRecord: instead to generate a new baseTransferRecord.
 */
- (CKTransferRecord *)baseTransferRecord
{
   return _baseTransferRecord;
}

#pragma mark Publishing

- (SVHTMLContext *)beginPublishingHTMLToPath:(NSString *)path;
{
    // Media gathering uses a single special context
    if (_currentContext) return _currentContext;
    
    // Make context
    NSMutableString *string = [[NSMutableString alloc] init];
    SVPublishingHTMLContext *result = [[SVPublishingHTMLContext alloc] initWithOutputWriter:string];
    [string release];
    
    [result setPublishingEngine:self];
    return [result autorelease];
}

/*	Use these methods instead of asking the connection directly. They will handle creating the
 *  appropriate directories first if needed.
 */
- (CKTransferRecord *)publishContentsOfURL:(NSURL *)localURL toPath:(NSString *)remotePath
{
	OBPRECONDITION(localURL);
    OBPRECONDITION([localURL isFileURL]);
    OBPRECONDITION(remotePath);
    
    if (![self shouldPublishToPath:remotePath]) return nil;
    
    
    CKTransferRecord *result = nil;
    
	
	BOOL isDirectory = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:[localURL path] isDirectory:&isDirectory])
    {
        // Is the URL actually a directory? If so, upload its contents
        if (isDirectory)
        {
            NSArray *subpaths = [[NSFileManager defaultManager] directoryContentsAtPath:[localURL path]];
            NSString *aSubPath;
            for (aSubPath in subpaths)
            {
                NSURL *aURL = [localURL URLByAppendingPathComponent:aSubPath isDirectory:NO];
                NSString *aRemotePath = [remotePath stringByAppendingPathComponent:aSubPath];
                [self publishContentsOfURL:aURL toPath:aRemotePath];
            }
        }
        else
        {
            // Create all required directories. Need to use -setName: otherwise the record will have the full path as its name
            CKTransferRecord *parent = [self createDirectory:[remotePath stringByDeletingLastPathComponent]];
            
            id <CKConnection> connection = [self connection];
            OBASSERT(connection);
            [connection connect];	// Ensure we're connected
            
            result = [connection uploadFile:[localURL path]
                                     toFile:remotePath
                       checkRemoteExistence:NO
                                   delegate:nil];
            
            [result setName:[remotePath lastPathComponent]];
            
            [self didQueueUpload:result toDirectory:parent];
        }
    }
    else
    {
        NSLog(@"Not uploading contents of %@ as it does not exist", [localURL path]);
    }
    
    
    return result;    
}

- (CKTransferRecord *)publishData:(NSData *)data toPath:(NSString *)remotePath
{
	OBPRECONDITION(data);
    OBPRECONDITION(remotePath);
    
    if (![self shouldPublishToPath:remotePath]) return nil;
    
    
    CKTransferRecord *parent = [self createDirectory:[remotePath stringByDeletingLastPathComponent]];
	
    id <CKConnection> connection = [self connection];
    OBASSERT(connection);
    [connection connect];	// Ensure we're connected
    CKTransferRecord *result = [connection uploadFromData:data toFile:remotePath checkRemoteExistence:NO delegate:nil];
    OBASSERT(result);
    [result setName:[remotePath lastPathComponent]];
    
    if (result)
    {
        [self didQueueUpload:result toDirectory:parent];
    }
    else
    {
        NSLog(@"Unable to create transfer record for path:%@ data:%@", remotePath, data); // case 40520 logging
    }
    
    
    // Record digest of the data for after publishing
    [result setProperty:[data SHA1HashDigest] forKey:@"dataDigest"];
    [result setProperty:remotePath forKey:@"path"];
    
    return result;
}
    
- (BOOL)shouldPublishToPath:(NSString *)path;
{
    BOOL result = ![_paths containsObject:path];
    return result;
}

- (void)didQueueUpload:(CKTransferRecord *)record toDirectory:(CKTransferRecord *)parent;
{
    [parent addContent:record];
    
    NSString *path = [record path];
    [_paths addObject:path];
    
    [[self connection] setPermissions:[self remoteFilePermissions]
                              forFile:path];
}

#pragma mark Media

- (void)gatherMedia;
{
    // Gather up media using special context
    SVMediaGatheringHTMLContext *context = [[SVMediaGatheringHTMLContext alloc] init];
    [context setPublishingEngine:self];
    
    SVMediaGatheringPublishingContext *pubContext = [[SVMediaGatheringPublishingContext alloc] init];
    [pubContext setPublishingEngine:self];
    
    _newMedia = [[NSMutableArray alloc] init];
    _currentContext = context;
    
    KTPage *homePage = [[self site] rootPage];
    [homePage publish:pubContext recursively:YES];
    
    _currentContext = nil;
    [context release];
    [pubContext release];
    
    // Assign filenames to the new media
    for (SVMediaRepresentation *mediaRep in _newMedia)
    {
        [self publishNewMediaRepresentation:mediaRep];
    }
    [_newMedia release]; _newMedia = nil;
}

- (NSString *)publishMediaRepresentation:(SVMediaRepresentation *)mediaRep;
{
    if ([self status] == KTPublishingEngineStatusGatheringMedia)
    {
        // Is there already an existing file on the server? If so, use that
        NSData *fileContents = [mediaRep data];
        NSData *digest = [fileContents SHA1HashDigest];
        
        SVPublishingRecord *publishingRecord = [[[self site] hostProperties] publishingRecordForSHA1Digest:digest];
        if (publishingRecord)
        {
            // Only upload the data if it's not already being done
            NSString *path = [publishingRecord path];
            if (![_paths containsObject:path])
            {
                [self publishData:fileContents toPath:path];
            }
            
            [_uploadedMediaReps setObject:path forKey:mediaRep];
        }
        else
        {
            // Put off uploading until all media has been gathered
            [_newMedia addObject:mediaRep];
        }
        
        return nil;
    }
    else
    {
        NSString *result = [_uploadedMediaReps objectForKey:mediaRep];
        return result;
    }
}

- (void)publishNewMediaRepresentation:(SVMediaRepresentation *)mediaRep
{
    //  The media rep does not already exist on the server, so need to assign it a new path
    id <SVMedia> media = [mediaRep mediaRecord];
    
    NSString *mediaDirectoryPath = [[self baseRemotePath] stringByAppendingPathComponent:@"_Media"];
    NSString *preferredFilename = [media preferredFilename];
    NSString *pathExtension = [preferredFilename pathExtension];
    
    NSString *legalizedFileName = [[preferredFilename stringByDeletingPathExtension]
                                   legalizedWebPublishingFileName];
    
    NSString *path = [mediaDirectoryPath stringByAppendingPathComponent:
                      [legalizedFileName stringByAppendingPathExtension:pathExtension]];
    
    NSUInteger count = 1;
    while ([_paths containsObject:path])
    {
        count++;
        NSString *fileName = [legalizedFileName stringByAppendingFormat:@"-%u", count];
        
        path = [mediaDirectoryPath stringByAppendingPathComponent:
                [fileName stringByAppendingPathExtension:pathExtension]];
    }
    
    
    // Upload
    NSData *fileContents = [mediaRep data];
    [self publishData:fileContents toPath:path];
    
    [_uploadedMediaReps setObject:path forKey:mediaRep];
}

@class KTMediaFile;

#pragma mark Resource Files

- (NSString *)publishResourceAtURL:(NSURL *)fileURL;
{
    NSString *resourcesDirectoryName = [[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultResourcesPath"];
    NSString *resourcesDirectoryPath = [[self baseRemotePath] stringByAppendingPathComponent:resourcesDirectoryName];
    NSString *resourceRemotePath = [resourcesDirectoryPath stringByAppendingPathComponent:[fileURL lastPathComponent]];
    
    [self publishContentsOfURL:fileURL toPath:resourceRemotePath];
    
    return resourceRemotePath;
}

#pragma mark Delegate

- (id <KTPublishingEngineDelegate>)delegate { return _delegate; }

- (void)setDelegate:(id <KTPublishingEngineDelegate>)delegate { _delegate = delegate; }

@end


#pragma mark -


@implementation KTPublishingEngine (SubclassSupport)

#pragma mark Overall flow control

/*  Call this method once publishing has ended, whether it be successfully or not.
 *  This method is responsible for cleaning up after publishing, and informing the delegate.
 */
- (void)engineDidPublish:(BOOL)didPublish error:(NSError *)error
{
    OBPRECONDITION([self status] > KTPublishingEngineStatusNotStarted && [self status] < KTPublishingEngineStatusFinished);
    
    
    // In the event of failure, end page parsing and media URL connections
    if (!didPublish)
    {
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
        
        // Disconnect connection
        [[self connection] forceDisconnect];
    }
    
    
    
    _status = KTPublishingEngineStatusFinished;
    
    [self setConnection:nil];
    
    
    // Inform the delegate
    if (didPublish)
    {
        [[self delegate] publishingEngineDidFinish:self];
    }
    else
    {
        [[self delegate] publishingEngine:self didFailWithError:error];
    }
    
    
    // Case 37891: Wipe the undo stack as we don't want the user to undo back past the publishing changes
    NSUndoManager *undoManager = [[[self site] managedObjectContext] undoManager];
    [undoManager removeAllActions];
}

#pragma mark Connection

/*  Simple accessor for the connection. If we haven't started uploading yet, or have finished, it returns nil.
 *  The -connect method is responsible for creating and storing the connection.
 */
- (id <CKConnection>)connection { return _connection; }

- (void)setConnection:(id <CKConnection>)connection
{
    [connection retain];
	
	[_connection setDelegate:nil];
	[_connection release];
	_connection = connection;
    
	[connection setDelegate:self];
}

/*  Subclasses should override to create a connection and call -setConection: with it. By default we use a file connection
 */
- (void)createConnection
{
    id <CKConnection> result = [[CKFileConnection alloc] init];
    OBASSERT(result);
    [self setConnection:result];
	[result release];
}

/*  Exporting shouldn't require any authentication
 */
- (void)connection:(id <CKConnection>)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
{
    [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
}

/*	Just pass on a simplified version of these 2 messages to our delegate
 */
- (void)connection:(id <CKConnection>)con uploadDidBegin:(NSString *)remotePath;
{
	[[self delegate] publishingEngine:self didBeginUploadToPath:remotePath];
}

- (void)connection:(id <CKConnection>)con upload:(NSString *)remotePath progressedTo:(NSNumber *)percent;
{
    if ([self status] <= KTPublishingEngineStatusUploading)
    {
        [[self delegate] publishingEngineDidUpdateProgress:self];
    }
}

- (void)connection:(id <CKConnection>)con didDisconnectFromHost:(NSString *)host;
{
    if (![self connection]) return; // we've already finished in which case
    
    OBPRECONDITION(con == [self connection]);
    OBPRECONDITION(con);
    
    
    // Case 39234: It looks like ConnectionKit is sending this delegate method in the event of the
    // data connection closing (or it might even be the command connection), probably due to a
    // period of inactivity. In such a case, it's really not a cause to consider publishing
    // finished! To see if I am right on this, we will log that such a scenario occurred for now.
    // Mike.
    
    if ([self status] == KTPublishingEngineStatusUploading &&
        ![con isConnected] &&
        [[(CKAbstractQueueConnection *)con commandQueue] count] == 0)
    {
        [self engineDidPublish:YES error:nil];
    }
    else
    {
        NSLog(@"%@ delegate method received, but connection still appears to be publishing", NSStringFromSelector(_cmd));
    }
}

/*  We either ignore the error and continue or fail and inform the delegate
 */
- (void)connection:(id <CKConnection>)con didReceiveError:(NSError *)error;
{
    if (con != [self connection]) return;
    
    
    
    if ([[error userInfo] objectForKey:ConnectionDirectoryExistsKey]) 
	{
		return; //don't alert users to the fact it already exists, silently fail
	}
	else if ([error code] == 550 || [[[error userInfo] objectForKey:@"protocol"] isEqualToString:@"createDirectory:"] )
	{
		return;
	}
	else if ([con isKindOfClass:NSClassFromString(@"WebDAVConnection")] && 
			 ([[[error userInfo] objectForKey:@"directory"] isEqualToString:@"/"] || [error code] == 409 || [error code] == 204 || [error code] == 404))
	{
		// web dav returns a 409 if we try to create / .... which is fair enough!
		// web dav returns a 204 if a file to delete is missing.
		// 404 if the file to delete doesn't exist
		
		return;
	}
	else if ([error code] == kSetPermissions) // File connection set permissions failed ... ignore this (why?)
	{
		return;
	}
	else
	{
		[self engineDidPublish:NO error:error];
	}
}

- (void)connection:(id <CKConnection>)connection appendString:(NSString *)string toTranscript:(CKTranscriptType)transcript
{
	string = [string stringByAppendingString:@"\n"];
	NSAttributedString *attributedString = [[connection class] attributedStringForString:string transcript:transcript];
	[[[KTTranscriptController sharedControllerWithoutLoading] textStorage] appendAttributedString:attributedString];
}

#pragma mark Pages

/*  Uploads the site map if the site has the option enabled
 */
- (void)uploadGoogleSiteMapIfNeeded
{
    if ([[self site] boolForKey:@"generateGoogleSitemap"])
    {
        NSString *sitemapXML = [[self site] googleSiteMapXMLString];
        NSData *siteMapData = [sitemapXML dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
        NSData *gzipped = [siteMapData compressGzip];
        
        NSString *siteMapPath = [[self baseRemotePath] stringByAppendingPathComponent:@"sitemap.xml.gz"];
        [self publishData:gzipped toPath:siteMapPath];
    }
}

/*  Slightly messy support method that allows KTPublishingEngine to reject publishing non-stale pages
 */
- (BOOL)shouldUploadHTML:(NSString *)HTML encoding:(NSStringEncoding)encoding forPage:(KTPage *)page toPath:(NSString *)uploadPath digest:(NSData **)outDigest;
{
    return YES;
}

- (void)publishNonPageContent
{
    /*
     KTMaster *master = [[[self site] rootPage] master];
     NSDictionary *scalingProps = [[master design] imageScalingPropertiesForUse:@"bannerImage"];
     KTMediaFileUpload *bannerImage = [[[master bannerImage] file] uploadForScalingProperties:scalingProps];
     if (bannerImage)
     {
     [self uploadMediaIfNeeded:bannerImage];
     }*/
    
    [self uploadDesignIfNeeded];
    [self uploadMainCSSIfNeeded];
    
    
    // Upload sitemap if the site has one
    [self uploadGoogleSiteMapIfNeeded];
    
    
    // Inform the delegate if there's no pending media. If there is, we'll inform once that is done
    _status = KTPublishingEngineStatusUploading;
    [[self delegate] publishingEngineDidFinishGeneratingContent:self];
    
    [[self connection] disconnect]; // Once everything is uploaded, disconnect
}

#pragma mark Design

- (void)uploadDesignIfNeeded
{
    KTDesign *design = [[[[self site] rootPage] master] design];
    
    
    // Create the design directory
	NSString *remoteDesignDirectoryPath = [[self baseRemotePath] stringByAppendingPathComponent:[design remotePath]];
	CKTransferRecord *designTransferRecord = [self createDirectory:remoteDesignDirectoryPath];
    [designTransferRecord setProperty:design forKey:@"object"];
    
    
    // Upload the design's resources
	NSEnumerator *resourcesEnumerator = [[design resourceFileURLs] objectEnumerator];
	NSURL *aResource;
	while (aResource = [resourcesEnumerator nextObject])
	{
		NSString *filename = [aResource lastPathComponent];
        if (![filename isEqualToString:@"main.css"])    // We handle uploading CSS separately
        {
            NSString *uploadPath = [remoteDesignDirectoryPath stringByAppendingPathComponent:filename];
            [self publishContentsOfURL:aResource toPath:uploadPath];
        }
	}
}

- (void)addGraphicalTextBlock:(SVHTMLTextBlock *)textBlock;
{
    KTMediaFileUpload *media = [[[textBlock graphicalTextMedia] file] defaultUpload];
	if (media)
	{
		[self uploadMediaIfNeeded:media];
        [_graphicalTextBlocks ks_addObject:textBlock forKey:[textBlock graphicalTextCSSID]];
    }
}

/*  KTRemotePublishingEngine uses digest to only upload this if it's changed
 */
- (CKTransferRecord *)uploadMainCSSIfNeeded
{
    CKTransferRecord *result = nil;
    
    
    // Load up the CSS from the design
    KTMaster *master = [[[self site] rootPage] master];     OBASSERT(master);
    KTDesign *design = [master design];     if (!design) NSLog(@"No design found");
    NSString *mainCSSPath = [[design bundle] pathForResource:@"main" ofType:@"css"];
    
    NSMutableString *mainCSS = nil;
    if (mainCSSPath)
    {
        NSError *error;
        mainCSS = [[[NSMutableString alloc] initWithContentsOfFile:mainCSSPath usedEncoding:NULL error:&error] autorelease];
        if (!mainCSS)
        {
            NSLog(@"Unable to load CSS from %@, error: %@", mainCSSPath, [[error debugDescription] condenseWhiteSpace]);
            
            NSLog(@"Attempting deprecated -initWithContentsOfFile: method instead");
            mainCSS = [[NSMutableString alloc] initWithContentsOfFile:mainCSSPath];
            if (!mainCSS)
            {
                NSLog(@"And that didn't work either!");
            }
        }
    }
    else
    {
        NSLog(@"main.css file could not be located in design: %@", [[design bundle] bundlePath]);
    }
    
    if (!mainCSS) mainCSS = [[[NSMutableString alloc] init] autorelease];
    
    
    
    // Append banner CSS
    [master writeBannerCSS];
    
    
    
    // Append graphical text CSS. Use alphabetical ordering to maintain, er, sameness between publishes
    NSArray *graphicalTextIDs = [[_graphicalTextBlocks allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSArray *graphicalTextBlocks = [_graphicalTextBlocks objectsForKeys:graphicalTextIDs notFoundMarker:[NSNull null]];
    
    SVHTMLTextBlock *aTextBlock;
    for (aTextBlock in graphicalTextBlocks)
    {
        KTMediaFile *aGraphicalText = [[aTextBlock graphicalTextMedia] file];
        
        NSString *path = [[NSBundle mainBundle] overridingPathForResource:@"imageReplacementEntry" ofType:@"txt"];
        OBASSERT(path);
        NSURL *url = [NSURL fileURLWithPath:path];
        
        NSError *textFileError;
        NSMutableString *CSS = [NSMutableString stringWithContentsOfURL:url
                                                       fallbackEncoding:NSUTF8StringEncoding
                                                                  error:&textFileError];
        if (CSS)
        {
            [CSS replace:@"_UNIQUEID_" with:[aTextBlock graphicalTextCSSID]];
            [CSS replace:@"_WIDTH_" with:[NSString stringWithFormat:@"%i", [aGraphicalText integerForKey:@"width"]]];
            [CSS replace:@"_HEIGHT_" with:[NSString stringWithFormat:@"%i", [aGraphicalText integerForKey:@"height"]]];
            
            NSString *baseMediaPath = [[aGraphicalText defaultUpload] pathRelativeToSite];
            NSString *mediaPath = [@".." stringByAppendingPathComponent:baseMediaPath];
            [CSS replace:@"_URL_" with:mediaPath];
            
            [mainCSS appendString:CSS];
        }
        else
        {
            NSLog(@"Unable to read in image replacement CSS from %@, error: %@",
                  url,
                  [[textFileError debugDescription] condenseWhiteSpace]);
        }
    }
    
    
    
    // Upload the CSS if needed
    NSData *mainCSSData = [[mainCSS unicodeNormalizedString] dataUsingEncoding:NSUTF8StringEncoding
                                                          allowLossyConversion:YES];
    
    NSString *remoteDesignDirectoryPath = [[self baseRemotePath] stringByAppendingPathComponent:[design remotePath]];
    NSString *cssUploadPath = [remoteDesignDirectoryPath stringByAppendingPathComponent:@"main.css"];
    
    NSData *digest = nil;
    if ([self shouldUploadMainCSSData:mainCSSData toPath:cssUploadPath digest:&digest])
    {
        result = [self publishData:mainCSSData toPath:cssUploadPath];
        
        if (digest)
        {
            [result setProperty:master forKey:@"object"];
        }
    }
    
    
    return result;
}

/*  KTRemotePublishingEngine overrides this to manage staleness
 */
- (BOOL)shouldUploadMainCSSData:(NSData *)mainCSSData toPath:(NSString *)path digest:(NSData **)outDigest;
{
    if (outDigest) *outDigest = nil;
    return YES;
}

// FIXME: This delegate method has been replaced by -[SVHTMLContext generatedTextBlocks]
- (void)HTMLParser:(SVHTMLTemplateParser *)parser didParseTextBlock:(SVHTMLTextBlock *)textBlock
{
	[self addGraphicalTextBlock:textBlock];
}

#pragma mark Uploading Support

/*  Creates the specified directory including any parent directories that haven't already been queued for creation.
 *  Returns a CKTransferRecord used to represent the directory during publishing.
 */
- (CKTransferRecord *)createDirectory:(NSString *)remotePath
{
    OBPRECONDITION(remotePath);
    
    
    if ([remotePath isEqualToString:@"/"] || [remotePath isEqualToString:@""]) // The root for absolute and relative paths
    {
        return [self rootTransferRecord];
    }
    
    
    // Ensure the parent directory is created first
    NSString *parentDirectoryPath = [remotePath stringByDeletingLastPathComponent];
    OBASSERT(![parentDirectoryPath isEqualToString:[remotePath standardizedPOSIXPath]]);
    CKTransferRecord *parent = [self createDirectory:parentDirectoryPath];
    
    
    // Create the directory if it hasn't been already
    CKTransferRecord *result = nil;
    int i;
    for (i = 0; i < [[parent contents] count]; i++)
    {
        CKTransferRecord *aRecord = [[parent contents] objectAtIndex:i];
        if ([[aRecord name] isEqualToString:[remotePath lastPathComponent]])
        {
            result = aRecord;
            break;
        }
    }
    
    if (!result)
    {
        // This code will not set permissions for the document root or its parent directories as the
        // document root is created before this code gets called
        [[self connection] createDirectory:remotePath permissions:[self remoteDirectoryPermissions]];
        result = [CKTransferRecord recordWithName:[remotePath lastPathComponent] size:0];
        [parent addContent:result];
    }
    
    return result;
}

/*  The POSIX permissions that should be applied to files and folders on the server.
 */

- (unsigned long)remoteFilePermissions
{
    unsigned long result = 0;
    
    NSString *perms = [[NSUserDefaults standardUserDefaults] stringForKey:@"pagePermissions"];
    if (perms)
    {
        if (![perms hasPrefix:@"0"])
        {
            perms = [NSString stringWithFormat:@"0%@", perms];
        }
        char *num = (char *)[perms UTF8String];
        unsigned int p;
        sscanf(num,"%o",&p);
        result = p;
    }
    
    // Fall back
    if (result == 0)
    {
        result = 0644;
    }
    
    
    return result;
}

- (unsigned long)remoteDirectoryPermissions
{
    unsigned long result = ([self remoteFilePermissions] | 0111);
    return result;
}

@end

