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
#import "KTMaster.h"
#import "SVMediaGatheringPublisher.h"
#import "SVImageMedia.h"
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
#import "KSURLUtilities.h"
#import "KSPathUtilities.h"

#import "KSCSSWriter.h"
#import "KSPlugInWrapper.h"
#import "KSThreadProxy.h"

#import "Debug.h"
#import "Registration.h"

int kMaxNumberOfFreePublishedPages = 8;	// This is the constant value of how many pages max to publish when it's the free/lite/demo/unlicensed state.

NSString *KTPublishingEngineErrorDomain = @"KTPublishingEngineError";


@interface KTPublishingEngine ()

- (void)publishMainCSSToPath:(NSString *)cssUploadPath;

- (void)setRootTransferRecord:(CKTransferRecord *)rootRecord;

- (CKTransferRecord *)uploadData:(NSData *)data toPath:(NSString *)remotePath;
- (CKTransferRecord *)uploadContentsOfURL:(NSURL *)localURL toPath:(NSString *)remotePath;

- (BOOL)shouldPublishToPath:(NSString *)path;
- (void)didEnqueueUpload:(CKTransferRecord *)record toDirectory:(CKTransferRecord *)parent;

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
    
    
    if (self = [self init])
	{
		_site = [site retain];
        
        _paths = [[NSMutableSet alloc] init];
        _pathsByDigest = [[NSMutableDictionary alloc] init];
        
        _plugInCSS = [[NSMutableArray alloc] init];
        
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
    [_pathsByDigest release];
    
    [_plugInCSS release];
	
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
    [self setRootTransferRecord:[CKTransferRecord rootRecordWithPath:[[self documentRootPath] ks_standardizedPOSIXPath]]];
    
    
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
    // Make context
    SVPublishingHTMLContext *result = [[SVPublishingHTMLContext alloc] initWithUploadPath:path
                                                                                publisher:self];
    
    return [result autorelease];
}

/*	Use these methods instead of asking the connection directly. They will handle creating the
 *  appropriate directories first if needed.
 */
- (void)publishContentsOfURL:(NSURL *)localURL toPath:(NSString *)remotePath
{
	[self publishContentsOfURL:localURL toPath:remotePath cachedSHA1Digest:nil object:nil];
}

- (void)publishContentsOfURL:(NSURL *)localURL
                      toPath:(NSString *)remotePath
            cachedSHA1Digest:(NSData *)digest  // save engine the trouble of calculating itself
                      object:(id <SVPublishedObject>)object;
{
    OBPRECONDITION(localURL);
    OBPRECONDITION(remotePath);
    
    if (![self shouldPublishToPath:remotePath]) return;
    
    
    // Non-file URLs need to be uploaded as data
    if (![localURL isFileURL])
    {
        // Ideally this code should be async to improve performance. But right now we're only using it to load banner, which is likely cached, so should be fast enough.
        NSData *data = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:localURL]
                                             returningResponse:NULL
                                                         error:NULL];
        
        if (data) [self publishData:data toPath:remotePath];
        return;
    }
    
    
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
                NSURL *aURL = [localURL ks_URLByAppendingPathComponent:aSubPath isDirectory:NO];
                NSString *aRemotePath = [remotePath stringByAppendingPathComponent:aSubPath];
                [self publishContentsOfURL:aURL toPath:aRemotePath];
            }
        }
        else
        {
            CKTransferRecord *result = [self uploadContentsOfURL:localURL toPath:remotePath];
            [self didEnqueueUpload:result toPath:remotePath cachedSHA1Digest:digest contentHash:nil object:object];
        }
    }
    else
    {
        NSLog(@"Not uploading contents of %@ as it does not exist", [localURL path]);
    }
}

- (void)publishData:(NSData *)data toPath:(NSString *)uploadPath;
{
    [self publishData:data toPath:uploadPath cachedSHA1Digest:nil contentHash:nil object:nil];
}

- (void)publishData:(NSData *)data
             toPath:(NSString *)remotePath
   cachedSHA1Digest:(NSData *)digest  // save engine the trouble of calculating itself
        contentHash:(NSData *)hash
             object:(id <SVPublishedObject>)object;
{
	OBPRECONDITION(data);
    OBPRECONDITION(remotePath);
    
    if (![self shouldPublishToPath:remotePath]) return;
    
	CKTransferRecord *result = [self uploadData:data toPath:remotePath];
    
    if (result)
    {
        [self didEnqueueUpload:result
                        toPath:remotePath
              cachedSHA1Digest:digest
                   contentHash:hash
                        object:object];
    }
}
    
- (BOOL)shouldPublishToPath:(NSString *)path;
{
    BOOL result = ![_paths containsObject:path];
    return result;
}

- (CKTransferRecord *)uploadContentsOfURL:(NSURL *)localURL toPath:(NSString *)remotePath
{
    CKTransferRecord *parent = [self willUploadToPath:remotePath];
    
    // Need to use -setName: otherwise the record will have the full path as its name            
    id <CKConnection> connection = [self connection];
    OBASSERT(connection);
    [connection connect];	// Ensure we're connected
    
    CKTransferRecord *result = [connection uploadFile:[localURL path]
                                               toFile:remotePath
                                 checkRemoteExistence:NO
                                             delegate:nil];
    
    [result setName:[remotePath lastPathComponent]];
    
    [self didEnqueueUpload:result toDirectory:parent];
    
    return result;
}

/*  Raw, get me some stuff on the server!
 */
- (CKTransferRecord *)uploadData:(NSData *)data toPath:(NSString *)remotePath;
{
    CKTransferRecord *parent = [self willUploadToPath:remotePath];
    
    id <CKConnection> connection = [self connection];
    OBASSERT(connection);
    [connection connect];	// Ensure we're connected
    CKTransferRecord *result = [connection uploadFromData:data toFile:remotePath checkRemoteExistence:NO delegate:nil];
    OBASSERT(result);
    [result setName:[remotePath lastPathComponent]];
    
    if (result)
    {
        [self didEnqueueUpload:result toDirectory:parent];
    }
    else
    {
        NSLog(@"Unable to create transfer record for path:%@ data:%@", remotePath, data); // case 40520 logging
    }
    
    return result;
}

- (CKTransferRecord *)willUploadToPath:(NSString *)path;
{
    CKTransferRecord *parent = [self createDirectory:[path stringByDeletingLastPathComponent]];
    return parent;
}

- (void)didEnqueueUpload:(CKTransferRecord *)record
                  toPath:(NSString *)path
        cachedSHA1Digest:(NSData *)digest
             contentHash:(NSData *)contentHash
                  object:(id <SVPublishedObject>)object;
{
    [_paths addObject:path];
    if (digest) [_pathsByDigest setObject:path forKey:digest];
}

- (void)didEnqueueUpload:(CKTransferRecord *)record toDirectory:(CKTransferRecord *)parent;
{
    [parent addContent:record];
    
    NSString *path = [record path];
    [[self connection] setPermissions:[self remoteFilePermissions]
                              forFile:path];
}

#pragma mark CSS

- (void)addCSSString:(NSString *)css;
{
    if (![_plugInCSS containsObject:css]) [_plugInCSS addObject:css];
}

- (void)addCSSWithURL:(NSURL *)cssURL;
{
    cssURL = [cssURL absoluteURL];
    if (![_plugInCSS containsObject:cssURL]) [_plugInCSS addObject:cssURL];
}

#pragma mark Design

- (NSString *)designDirectoryPath;
{
    KTDesign *design = [[[[self site] rootPage] master] design];
    NSString *result = [[self baseRemotePath] stringByAppendingPathComponent:[design remotePath]];
    return result;
}

- (void)publishDesign
{
    KTPage *rootPage = [[self site] rootPage];
    KTMaster *master = [rootPage master];
    KTDesign *design = [master design];
    [design writeCSS:(id)self];
    [master writeBannerCSS:(id)self];
	[master writeCodeInjectionCSS:self];

    
    NSString *remoteDesignDirectoryPath = [self designDirectoryPath];    
    
    // Upload the design's resources
	NSEnumerator *resourcesEnumerator = [[design resourceFileURLs] objectEnumerator];
	NSURL *aResource;
	while (aResource = [resourcesEnumerator nextObject])
	{
		NSString *filename = [aResource ks_lastPathComponent];
        NSString *uploadPath = [remoteDesignDirectoryPath stringByAppendingPathComponent:filename];
        
        if ([filename isEqualToString:@"main.css"])
        {
            [self publishMainCSSToPath:uploadPath];
        }
        else
        {
            [self publishContentsOfURL:aResource toPath:uploadPath];
        }
	}
}

@class KTMediaFile;

/*  KTRemotePublishingEngine uses digest to only upload this if it's changed
 */
- (void)publishMainCSSToPath:(NSString *)cssUploadPath;
{
    NSMutableString *css = [NSMutableString string];
    KSCSSWriter *cssWriter = [[KSCSSWriter alloc] initWithOutputWriter:css];
    
    
    // Write CSS
    for (id someCSS in _plugInCSS)
    {
        if ([someCSS isKindOfClass:[NSURL class]])
        {
            NSString *css = [NSString stringWithContentsOfURL:someCSS
                                             fallbackEncoding:NSUTF8StringEncoding
                                                        error:NULL];
            
            if (css)
			{
#ifdef VARIANT_BETA
				[cssWriter writeCSSString:
				 [NSString stringWithFormat:@"/* ----------- Source: %@ ----------- */",
				  [[someCSS path] lastPathComponent]]];
#endif
				[cssWriter writeCSSString:css];

#ifdef VARIANT_BETA
				[cssWriter writeCSSString:
				 [NSString stringWithFormat:@"/* ----------- End:    %@ ----------- */",
				  [[someCSS path] lastPathComponent]]];
#endif
			}
        }
        else
        {
            [cssWriter writeCSSString:someCSS];
        }
    }
    
    [cssWriter release];
    
    
    
    // Upload the CSS if needed
    NSData *mainCSSData = [[css unicodeNormalizedString] dataUsingEncoding:NSUTF8StringEncoding
                                                      allowLossyConversion:YES];
    
    [self publishData:mainCSSData toPath:cssUploadPath];
}

- (NSURL *)addBannerWithURL:(NSURL *)sourceURL;
{
    // Publish source
    NSString *bannerPath = [[self designDirectoryPath] stringByAppendingPathComponent:@"banner.jpeg"];
    [self publishContentsOfURL:sourceURL toPath:bannerPath];
    
    // Where will it be published to?
    NSURL *designURL = [[[[self site] rootPage] master] designDirectoryURL];
    NSURL *result = [designURL ks_URLByAppendingPathComponent:@"banner.jpeg" isDirectory:NO];
    return result;
}

- (void)addDependencyOnObject:(NSObject *)object keyPath:(NSString *)keyPath { }

#pragma mark Media

- (void)gatherMedia;
{
    // Publish any media that has been published before (so it maintains its path). Ignore all else
    SVMediaGatheringPublisher *pubContext = [[SVMediaGatheringPublisher alloc] init];
    [pubContext setPublishingEngine:self];
    
    KTPage *homePage = [[self site] rootPage];
    [homePage publish:pubContext recursively:YES];
    
    [pubContext release];
}

- (NSString *)publishMedia:(id <SVMedia>)media;
{
    // Is there already an existing file on the server? If so, use that
    NSData *fileContents = [media mediaData];
    if (!fileContents) fileContents = [NSData dataWithContentsOfURL:[media mediaURL]];
    NSData *digest = [fileContents SHA1Digest];
    
    NSString *result = [self pathForFileWithSHA1Digest:digest];
    if (!result)
    {
        // New media should only be published once we know where all the existing stuff is going
        if ([self status] > KTPublishingEngineStatusGatheringMedia)
        {
            //  The media rep does not already exist on the server, so need to assign it a new path
            NSString *mediaDirectoryPath = [[self baseRemotePath] stringByAppendingPathComponent:@"_Media"];
            NSString *preferredFilename = [media preferredFilename];
            NSString *pathExtension = [preferredFilename pathExtension];
            
            NSString *legalizedFileName = [[preferredFilename stringByDeletingPathExtension]
                                           legalizedWebPublishingFileName];
            
            result = [mediaDirectoryPath stringByAppendingPathComponent:
                              [legalizedFileName stringByAppendingPathExtension:pathExtension]];
            
            NSUInteger count = 1;
            while (![self shouldPublishToPath:result])
            {
                count++;
                NSString *fileName = [legalizedFileName stringByAppendingFormat:@"-%u", count];
                
                result = [mediaDirectoryPath stringByAppendingPathComponent:
                        [fileName stringByAppendingPathExtension:pathExtension]];
            }
            
            OBASSERT(result);
        }
    }
    
    
    // Publish!
    if (result)
    {
        [self publishData:fileContents
                   toPath:result
         cachedSHA1Digest:digest
              contentHash:nil
                   object:nil];
    }
    
    return result;
}

#pragma mark Resource Files

- (NSString *)publishResourceAtURL:(NSURL *)fileURL;
{
    NSString *resourcesDirectoryName = [[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultResourcesPath"];
    NSString *resourcesDirectoryPath = [[self baseRemotePath] stringByAppendingPathComponent:resourcesDirectoryName];
    NSString *resourceRemotePath = [resourcesDirectoryPath stringByAppendingPathComponent:[fileURL ks_lastPathComponent]];
    
    [self publishContentsOfURL:fileURL toPath:resourceRemotePath];
    
    return resourceRemotePath;
}

#pragma mark Publishing Records

- (NSString *)pathForFileWithSHA1Digest:(NSData *)digest;
{
    OBPRECONDITION(digest);
    
    NSString *result = [_pathsByDigest objectForKey:digest];
    
    if (!result)
    {
        SVPublishingRecord *publishingRecord = [[[self site] hostProperties]
                                                publishingRecordForSHA1Digest:digest];
        
        result = [publishingRecord path];
    }
    
    return result;
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
    
    [self publishDesign];
    
    
    [self finishPublishing];
}

- (void)finishPublishing;
{
    // Upload sitemap if the site has one
    [self uploadGoogleSiteMapIfNeeded];
    
    
    // Inform the delegate if there's no pending media. If there is, we'll inform once that is done
    _status = KTPublishingEngineStatusUploading;
    [[self delegate] publishingEngineDidFinishGeneratingContent:self];
    
    [[self connection] disconnect];
    // Once everything is uploaded, disconnect
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
    OBASSERT(![parentDirectoryPath isEqualToString:[remotePath ks_standardizedPOSIXPath]]);
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

