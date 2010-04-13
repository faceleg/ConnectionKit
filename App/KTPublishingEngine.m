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


NSString *KTPublishingEngineErrorDomain = @"KTPublishingEngineError";


#define KTParsingInterval 0.1


@interface KTPublishingEngine ()

- (void)setRootTransferRecord:(CKTransferRecord *)rootRecord;

- (void)didQueueUpload:(CKTransferRecord *)record toDirectory:(CKTransferRecord *)parent;

@end


@interface KTPublishingEngine (SubclassSupportPrivate)

- (void)_parseAndUploadPageIfNeeded:(KTPage *)page;
- (void)publishNonPageContent;

// Media
- (void)gatherMedia;
- (void)queuePendingMedia:(KTMediaFileUpload *)media;
- (void)dequeuePendingMedia;

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
        _uploadedMedia = [[NSMutableSet alloc] init];
        _pendingMediaUploads = [[NSMutableArray alloc] init];
        _resourceFiles = [[NSMutableSet alloc] init];
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
    OBASSERT([_pendingMediaUploads count] == 0);
    [_pendingMediaUploads release];
    OBASSERT(!_currentPendingMediaConnection);
    [_uploadedMedia release];
    
    [_resourceFiles release];
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
    _status = KTPublishingEngineStatusParsing;
    
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
    SVPublishingHTMLContext *result = [[SVPublishingHTMLContext alloc] initWithStringWriter:string];
    [string release];
    
    [result setPublishingEngine:self];
    return [result autorelease];
}

/*	Use these methods instead of asking the connection directly. They will handle creating the
 *  appropriate directories first if needed.
 */
- (CKTransferRecord *)uploadContentsOfURL:(NSURL *)localURL toPath:(NSString *)remotePath
{
	OBPRECONDITION(localURL);
    OBPRECONDITION([localURL isFileURL]);
    OBPRECONDITION(remotePath);
    
    
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
                [self uploadContentsOfURL:aURL toPath:aRemotePath];
            }
        }
        else
        {
            // Create all required directories. Need to use -setName: otherwise the record will have the full path as its name
            CKTransferRecord *parent = [self createDirectory:[remotePath stringByDeletingLastPathComponent]];
            
            id <CKConnection> connection = [self connection];
            OBASSERT(connection);
            [connection connect];	// Ensure we're connected
            result = [connection uploadFile:[localURL path] toFile:remotePath checkRemoteExistence:NO delegate:nil];
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

- (CKTransferRecord *)uploadData:(NSData *)data toPath:(NSString *)remotePath
{
	OBPRECONDITION(data);
    OBPRECONDITION(remotePath);
    
    
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
         
- (void)didQueueUpload:(CKTransferRecord *)record toDirectory:(CKTransferRecord *)parent;
{
    [parent addContent:record];
    
    NSString *path = [record path];
    [_paths addObject:path];
    
    [[self connection] setPermissions:[self remoteFilePermissions]
                              forFile:path];
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
        
        if ([_pendingMediaUploads count] > 0)
        {
            [_currentPendingMediaConnection cancel];
            [_currentPendingMediaConnection release];   _currentPendingMediaConnection = nil;
            [_pendingMediaUploads removeAllObjects];
        }
        
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
        [self uploadData:gzipped toPath:siteMapPath];
    }
}

/*!
 Unused. Left over from 1.6 code so I can copy out functionality
 */
- (void)_parseAndUploadPageIfNeeded:(KTPage *)item
{
	OBASSERT([NSThread isMainThread]);
	
	
    // Don't publish drafts or special pages with no direct content
    if ([item isDraftOrHasDraftAncestor]) return;
    
    
    
    // Bail early if the page is not for publishing. This MUST come after testing if the page is a
    // File Download, as they have no upload path, but still need to process media. Case 40515.
	NSString *uploadPath = [item uploadPath];
	if (!uploadPath) return;
    
    
	
	// Generate HTML data
	NSMutableString *HTML = [[NSMutableString alloc] init];
    
    SVPublishingHTMLContext *context = [[SVPublishingHTMLContext alloc]
                                        initWithStringWriter:HTML];
    [context setCurrentPage:item];
	
	[item writeHTML:context];
    [context release];
    
    KTPage *masterPage = ([item isKindOfClass:[KTPage class]]) ? (KTPage *)item : [item parentPage];
    
    if ([self status] > KTPublishingEngineStatusUploading) return; // Engine may be cancelled mid-parse. If so, go no further.
	
	NSString *charset = [[masterPage master] valueForKey:@"charset"];
	NSStringEncoding encoding = [charset encodingFromCharset];
	NSData *pageData = [HTML dataUsingEncoding:encoding allowLossyConversion:YES];
	OBASSERT(pageData);
    
    
    // Give subclasses a chance to ignore the upload
    NSString *fullUploadPath = [[self baseRemotePath] stringByAppendingPathComponent:uploadPath];
	
    NSData *digest = nil;
    if (![self shouldUploadHTML:HTML encoding:encoding forPage:item toPath:fullUploadPath digest:&digest])
    {
        return;
    }
    
    
    
    // Upload page data. Store the page and its digest with the record for processing later
    if (fullUploadPath)
    {
		CKTransferRecord *transferRecord = [self uploadData:pageData toPath:fullUploadPath];
        OBASSERT(transferRecord);
        
        [transferRecord setProperty:item forKey:@"object"];
	}
    
    
	// Ask the delegate for any extra resource files that the parser didn't catch
    if ([item isKindOfClass:[KTPage class]])
    {
        NSMutableSet *resources = [[NSMutableSet alloc] init];
        
        
        NSString *aResourcePath;
        for (aResourcePath in resources)
        {
            [self addResourceFile:[NSURL fileURLWithPath:aResourcePath]];
        }
        
        [resources release];
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
    
    
    // Upload resources. KTLocalPublishingEngine & subclasses use this point to bail out if
    // there are no changes to publish
    if ([self uploadResourceFiles])
    {
        // Upload sitemap if the site has one
        [self uploadGoogleSiteMapIfNeeded];
        
        
        // Inform the delegate if there's no pending media. If there is, we'll inform once that is done
        if ([_pendingMediaUploads count] == 0)
        {
            _status = KTPublishingEngineStatusUploading;
            [[self delegate] publishingEngineDidFinishGeneratingContent:self];
            
            [[self connection] disconnect]; // Once everything is uploaded, disconnect
        }
        else
        {
            _status = KTPublishingEngineStatusLoadingMedia;
        }
    }
}

#pragma mark Media

- (void)gatherMedia;
{
    // Gather up media using special context
    SVMediaGatheringHTMLContext *context = [[SVMediaGatheringHTMLContext alloc] init];
    [context setPublishingEngine:self];
    
    _newMedia = [[NSMutableArray alloc] init];
    _currentContext = context;
    
    KTPage *homePage = [[self site] rootPage];
    [homePage publish:self recursively:YES];
    
    _currentContext = nil;
    [context release];
    
    
    // Assign filenames to the new media
    for (SVMediaRepresentation *mediaRep in _newMedia)
    {
        id <SVMedia> media = [mediaRep mediaRecord];
        
        NSString *path = [[[self baseRemotePath]
                           stringByAppendingPathComponent:@"_Media"]
                          stringByAppendingPathComponent:[media preferredFilename]];
        
        NSData *fileContents = [mediaRep data];
        [self uploadData:fileContents toPath:path];
    }
    
    [_newMedia release]; _newMedia = nil;
}

- (void)publishMediaRepresentation:(SVMediaRepresentation *)mediaRep;
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
            [self uploadData:fileContents toPath:path];
        }
    }
    else
    {
        // Put off uploading until all media has been gathered
        [_newMedia addObject:mediaRep];
    }
}

- (NSSet *)uploadedMedia
{
    return [[_uploadedMedia copy] autorelease];
}

@class KTMediaFile;

/*  Adds the media file to the upload queue (if it's not already in it)
 */
- (void)uploadMediaIfNeeded:(KTMediaFileUpload *)media
{
    if (![_uploadedMedia containsObject:media])    // Don't bother if it's already in the queue
    {
        KTMediaFile *mediaFile = [media valueForKey:@"file"];
		NSString *sourcePath = [mediaFile currentPath];
		if (sourcePath)
		{
			NSURL *URL = [mediaFile URLForImageScalingProperties:[media scalingProperties]];
            OBASSERT(URL);
            
            
            if ([URL isFileURL])
            {
                // Upload the media. Store the media object with the transfer record for processing later
				NSString *uploadPath = [[self baseRemotePath] stringByAppendingPathComponent:[media pathRelativeToSite]];
                OBASSERT(uploadPath);
                
                CKTransferRecord *transferRecord = [self uploadContentsOfURL:[NSURL fileURLWithPath:sourcePath] toPath:uploadPath];
                [transferRecord setProperty:media forKey:@"object"];
			}
            else
            {
                // Asynchronously load the data and then upload it
                [self queuePendingMedia:media];
            }
            
            
            // Record that we're uploading the object
            [_uploadedMedia addObject:media];
		}
	}
}
				
/*  Upload the media if needed
 */
- (void)HTMLParser:(SVHTMLTemplateParser *)parser didParseMediaFile:(KTMediaFile *)mediaFile upload:(KTMediaFileUpload *)upload;	
{
    // It used to be possible for the connection to be cancelled mid-parse. If so, just ignore the media
    if (upload) // && [self status] <= KTPublishingEngineStatusUploading)
	{
		[self uploadMediaIfNeeded:upload];
	}
}

- (void)queuePendingMedia:(KTMediaFileUpload *)media
{
    [_pendingMediaUploads addObject:media];
    
    // Kick off processing if this is the first item on the queue
    if ([_pendingMediaUploads count] == 1)
    {
        [self dequeuePendingMedia];
    }
}

- (void)dequeuePendingMedia
{
    KTMediaFileUpload *media = [_pendingMediaUploads objectAtIndex:0];
    KTMediaFile *mediaFile = [media valueForKey:@"file"];
    NSURLRequest *URLRequest = [mediaFile URLRequestForImageScalingProperties:[media scalingProperties]];
    OBASSERT(URLRequest);
    _currentPendingMediaConnection = [[KSSimpleURLConnection alloc] initWithRequest:URLRequest delegate:self];
}

- (void)connection:(KSSimpleURLConnection *)connection didFinishLoadingData:(NSData *)data response:(NSURLResponse *)response
{
    OBPRECONDITION(connection == _currentPendingMediaConnection);
    
    
    KTMediaFileUpload *media = [_pendingMediaUploads objectAtIndex:0];
    NSString *uploadPath = [[self baseRemotePath] stringByAppendingPathComponent:[media pathRelativeToSite]];
    OBASSERT(uploadPath);
    
    CKTransferRecord *transferRecord = [self uploadData:data toPath:uploadPath];
    [transferRecord setProperty:media forKey:@"object"];
    
    // Tidy up after the connection
    [self connection:connection didFailWithError:nil];
}

- (void)connection:(KSSimpleURLConnection *)connection didFailWithError:(NSError *)error
{
    if (error)
    {
        NSLog(@"Media connection for publishing failed: %@", [error debugDescription]);
    }
    
    
    OBPRECONDITION(connection == _currentPendingMediaConnection);
    [_currentPendingMediaConnection release];   _currentPendingMediaConnection = nil;
    
    
    // Remove from the queue and start the next item if available
    [_pendingMediaUploads removeObjectAtIndex:0];
    if ([_pendingMediaUploads count] > 0)
    {
        [self dequeuePendingMedia];
    }
    else if ([self status] == KTPublishingEngineStatusLoadingMedia)
    {
        // If all content has been generated and there's no more media to load, queue the final
        // disconnect command and inform the delegate
        _status = KTPublishingEngineStatusUploading;
        [[self delegate] publishingEngineDidFinishGeneratingContent:self];
        
        [[self connection] disconnect];
    }
}

#pragma mark -
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
            [self uploadContentsOfURL:aResource toPath:uploadPath];
        }
	}
}

- (void)addGraphicalTextBlock:(SVHTMLTextBlock *)textBlock;
{
    KTMediaFileUpload *media = [[[textBlock graphicalTextMedia] file] defaultUpload];
	if (media)
	{
		[self uploadMediaIfNeeded:media];
        [_graphicalTextBlocks addObject:textBlock forKey:[textBlock graphicalTextCSSID]];
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
        result = [self uploadData:mainCSSData toPath:cssUploadPath];
        
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

#pragma mark -
#pragma mark Resource Files

- (NSSet *)resourceFiles
{
    return [[_resourceFiles copy] autorelease];
}

- (void)addResourceFile:(NSURL *)resourceURL
{
    resourceURL = [resourceURL absoluteURL];    // Ensures hashing and -isEqual: work right
    
    if (![_resourceFiles containsObject:resourceURL])
    {
        [_resourceFiles addObject:resourceURL];
    }
}

- (void)HTMLParser:(SVHTMLTemplateParser *)parser didEncounterResourceFile:(NSURL *)resourceURL
{
	OBPRECONDITION(resourceURL);
    [self addResourceFile:resourceURL];
}

/*  Takes all the queued up resource files and uploads them. KTRemotePublishingEngine uses this as
 *  the cut-in point for if there are no changes to publish. Return NO to signify publishing should
 *  not continue.
 */
- (BOOL)uploadResourceFiles
{
    NSString *resourcesDirectoryName = [[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultResourcesPath"];
    NSString *resourcesDirectoryPath = [[self baseRemotePath] stringByAppendingPathComponent:resourcesDirectoryName];
    
    NSEnumerator *resourcesEnumerator = [[self resourceFiles] objectEnumerator];
    NSURL *aResource;
    while (aResource = [resourcesEnumerator nextObject])
    {
        NSString *resourceRemotePath = [resourcesDirectoryPath stringByAppendingPathComponent:[aResource lastPathComponent]];
        
        [self uploadContentsOfURL:aResource toPath:resourceRemotePath];
    }
    
    return YES;
}

#pragma mark -
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

