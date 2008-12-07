//
//  KTTransferController.m
//  Marvel
//
//  Created by Terrence Talbot on 10/30/08.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTTransferController.h"
#import "NSString+Publishing.h"

#import "KTAbstractElement+Internal.h"
#import "KTAbstractPage+Internal.h"
#import "KTDesign.h"
#import "KTDocumentInfo.h"
#import "KTMaster+Internal.h"
#import "KTPage+Internal.h"

#import "KTMediaContainer.h"
#import "KTMediaFile.h"
#import "KTMediaFileUpload.h"

#import "NSBundle+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSThread+Karelia.h"
#import "NSURL+Karelia.h"

#import "KSPlugin.h"
#import "KSThreadProxy.h"
#import "KSUtilities.h"

#import "Debug.h"
#import "Registration.h"


@interface KTTransferController (Private)
- (void)uploadPage:(KTAbstractPage *)page;

- (void)uploadDesign;
- (void)_uploadMainCSSAndGraphicalText:(NSURL *)mainCSSFileURL remoteDesignDirectoryPath:(NSString *)remoteDesignDirectoryPath;

- (void)uploadMediaIfNeeded:(KTMediaFileUpload *)media;

- (void)uploadResourceIfNeeded:(NSURL *)resourceURL;

- (CKTransferRecord *)uploadContentsOfURL:(NSURL *)localURL toPath:(NSString *)remotePath;
- (CKTransferRecord *)uploadData:(NSData *)data toPath:(NSString *)remotePath;
- (CKTransferRecord *)createDirectory:(NSString *)remotePath;

- (CKTransferRecord *)rootTransferRecord;
@end


#pragma mark -


@implementation KTTransferController

#pragma mark -
#pragma mark Init & Dealloc

- (id)initWithDocumentInfo:(KTDocumentInfo *)aDocumentInfo onlyPublishChanges:(BOOL)publishChanges;
{
	[super init];
	if ( nil != self )
	{
		myDocumentInfo = [aDocumentInfo retain];
        myOnlyPublishChanges = publishChanges;
        
        myUploadedMedia = [[NSMutableSet alloc] init];
        myUploadedResources = [[NSMutableSet alloc] init];
	}
	
	return self;
}

- (void)dealloc
{
	[myDocumentInfo release];
	OBASSERT(!myConnection);	// TODO: Gracefully close connection
    [_rootTransferRecord release];
    [myUploadedMedia release];
    [myUploadedResources release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (KTDocumentInfo *)documentInfo
{
	return myDocumentInfo;
}

- (BOOL)onlyPublishChanges { return myOnlyPublishChanges; }

#pragma mark -
#pragma mark Connection

/*  Simple accessor for the connection. If we haven't started uploading yet, or have finished, it returns nil.
 *  The -startUploading method is responsible for creating and storing the connection.
 */
- (id <CKConnection>)connection
{
	return myConnection;
}

- (void)connect
{
    KTHostProperties *hostProperties = [[self documentInfo] hostProperties];
    
    NSString *hostName = [hostProperties valueForKey:@"hostName"];
    NSString *protocol = [hostProperties valueForKey:@"protocol"];
    
    NSNumber *port = [hostProperties valueForKey:@"port"];
    
    myConnection = [[CKConnectionRegistry sharedConnectionRegistry] connectionWithName:protocol
                                                                                  host:hostName
                                                                                  port:port];
    [myConnection retain];
    [myConnection setDelegate:self];
    [myConnection connect];
}

/*  Authenticate the connection
 */
- (void)connection:(id <CKConnection>)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
{
    KTHostProperties *hostProperties = [[self documentInfo] hostProperties];
    
    NSString *password = nil;
    NSString *userName = [hostProperties valueForKey:@"userName"];
    NSString *protocol = [hostProperties valueForKey:@"protocol"];

        
    if (userName && ![userName isEqualToString:@""])
    {
        [[EMKeychainProxy sharedProxy] setLogsErrors:YES];
        EMInternetKeychainItem *keychainItem = [[EMKeychainProxy sharedProxy] internetKeychainItemForServer:[[connection URL] host]
                                                                                               withUsername:userName 
                                                                                                       path:nil 
                                                                                                       port:[(CKAbstractConnection *)connection port] 
                                                                                                   protocol:[KSUtilities SecProtocolTypeForProtocol:protocol]];
        [[EMKeychainProxy sharedProxy] setLogsErrors:NO];
        if ( nil == keychainItem )
        {
            NSLog(@"warning: publisher did not find keychain item for server %@, user %@", [[connection URL] host], userName);
        }
        
        password = [keychainItem password];
    }
    
    
    NSURLCredential *credential = [[NSURLCredential alloc] initWithUser:userName password:password persistence:NSURLCredentialPersistenceNone];
    [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
    [credential release];
}

/*  The root directory that all content goes into. For normal publishing this is "documentRoot/subfolder"
 */
- (NSString *)baseRemotePath
{
	KTHostProperties *hostProperties = [[self documentInfo] hostProperties];
    NSString *result = [[hostProperties valueForKey:@"docRoot"] stringByAppendingPathComponent:[hostProperties valueForKey:@"subFolder"]];
    return result;
}

#pragma mark -
#pragma mark Content Generation

- (void)startUploading
{
	// Create connection
    [self connect];
    
    
	// In demo mode, only publish the home page
	NSArray *pagesToParse;
	if (!gLicenseIsBlacklisted && (nil != gRegistrationString))	// License is OK
	{
		pagesToParse = [KTAbstractPage allPagesInManagedObjectContext:[[self documentInfo] managedObjectContext]];
	}
	else
	{
		pagesToParse = [NSArray arrayWithObject:[[self documentInfo] root]];
	}
	
	
	// Parsing every page is a long process so do it on a background thread
	[NSThread detachNewThreadSelector:@selector(threadedGenerateContentFromPages:)
							 toTarget:self
						   withObject:pagesToParse];
}

/*	Public method that parses each page in the site and uploads what's needed
 */
- (void)threadedGenerateContentFromPages:(NSArray *)pages
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSEnumerator *pagesEnumerator = [pages objectEnumerator];
	KTAbstractPage *aPage;
	
	while (aPage = [pagesEnumerator nextObject])
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		[[self proxyForThread:nil] uploadPage:aPage];
		[pool release];
	}
	
	
	// Upload design
    [[self proxyForThread:nil] uploadDesign];
	
	
	
	[pool release];
}

#pragma mark -
#pragma mark Pages

- (void)uploadPage:(KTAbstractPage *)page
{
	OBASSERT([NSThread isMainThread]);
	
	
    // Bail early if the page is not for publishing
	NSString *uploadPath = [page uploadPath];
	if (!uploadPath) return;
	
	if ([page isKindOfClass:[KTPage class]])
	{
		// This is currently a special case to make sure Download Page media is published
		// We really ought to generalise this feature if any other plugins actually need it
		if ([[[[page plugin] bundle] bundleIdentifier] isEqualToString:@"sandvox.DownloadElement"])
		{
			KTMediaFileUpload *upload = [[page delegate] performSelector:@selector(mediaFileUpload)];
			if (upload)
			{
				[self uploadMediaIfNeeded:upload];
			}
		}
		
		// Don't publish drafts or special pages with no direct content
		if ([(KTPage *)page pageOrParentDraft] || ![(KTPage *)page shouldPublishHTMLTemplate]) return;
	}
			
	
	// Generate HTML data
	KTPage *masterPage = ([page isKindOfClass:[KTPage class]]) ? (KTPage *)page : [page parent];
	NSString *HTML = [[page contentHTMLWithParserDelegate:self isPreview:NO] stringByAdjustingHTMLForPublishing];
	OBASSERT(HTML);
	
	NSString *charset = [[masterPage master] valueForKey:@"charset"];
	NSStringEncoding encoding = [charset encodingFromCharset];
	NSData *pageData = [HTML dataUsingEncoding:encoding allowLossyConversion:YES];
	OBASSERT(pageData);
	
	
	// Don't upload if the page isn't stale and we've been requested to only publish changes
	if ([self onlyPublishChanges])
    {
        // The digest has to ignore the app version string
        NSString *versionString = [NSString stringWithFormat:@"<meta name=\"generator\" content=\"%@\" />",
                                   [[self documentInfo] appNameVersion]];
        NSString *versionFreeHTML = [HTML stringByReplacing:versionString with:@"<meta name=\"generator\" content=\"Sandvox\" />"];
        
        NSData *digest = [[versionFreeHTML dataUsingEncoding:encoding allowLossyConversion:YES] sha1Digest];
        NSData *publishedDataDigest = [page publishedDataDigest];
        NSString *publishedPath = [page publishedPath];
        
        if (publishedDataDigest &&
            (!publishedPath || [uploadPath isEqualToString:publishedPath]) &&   // 1.5.1 and earlier didn't store -publishedPath
            [publishedDataDigest isEqualToData:digest])
        {
            return;
        }
    }
    
    
    // Upload page data
    NSString *fullUploadPath = [[self baseRemotePath] stringByAppendingPathComponent:uploadPath];
	if (fullUploadPath)
    {
		[self uploadData:pageData toPath:fullUploadPath];
	}


	// Ask the delegate for any extra resource files that the parser didn't catch
    if ([page isKindOfClass:[KTPage class]])
    {
        NSMutableSet *resources = [[NSMutableSet alloc] init];
        [(KTPage *)page makeComponentsPerformSelector:@selector(addResourcesToSet:forPage:) 
                                           withObject:resources 
                                             withPage:(KTPage *)page 
                                            recursive:NO];
        
        NSEnumerator *resourcesEnumerator = [resources objectEnumerator];
        NSString *aResourcePath;
        while (aResourcePath = [resourcesEnumerator nextObject])
        {
            [self uploadResourceIfNeeded:[NSURL fileURLWithPath:aResourcePath]];
        }
        
        [resources release];
    }
	
	

	// Generate and publish RSS feed if needed
	if ([page isKindOfClass:[KTPage class]] && [page boolForKey:@"collectionSyndicate"] && [(KTPage *)page collectionCanSyndicate])
	{
		NSString *RSSString = [(KTPage *)page RSSFeedWithParserDelegate:self];
		if (RSSString)
		{			
			// Now that we have page contents in unicode, clean up to the desired character encoding.
			NSData *RSSData = [RSSString dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
			OBASSERT(RSSData);
			
			NSString *RSSFilename = [[NSUserDefaults standardUserDefaults] objectForKey:@"RSSFileName"];
			NSString *RSSUploadPath = [[fullUploadPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:RSSFilename];
			[self uploadData:RSSData toPath:RSSUploadPath];
		}
	}
}

#pragma mark -
#pragma mark Design

- (void)uploadDesign
{
    KTMaster *master = [[[self documentInfo] root] master];
    
    // Upload the design if its published version is different to the current one
    KTDesign *design = [master design];
    if ([[design marketingVersion] isEqualToString:[master valueForKeyPath:@"designPublishingInfo.versionLastPublished"]])
    {
        return;
    }
    
    
	KTMediaFileUpload *bannerImage = [[[master scaledBanner] file] defaultUpload];
	if (bannerImage)
	{
		[self uploadMediaIfNeeded:bannerImage];
	}
    
    
    
    NSString *remoteDesignDirectoryPath = [[self baseRemotePath] stringByAppendingPathComponent:[design remotePath]];
	
	
	// Upload the design's resources
	NSEnumerator *resourcesEnumerator = [[design resourceFileURLs] objectEnumerator];
	NSURL *aResource;
	while (aResource = [resourcesEnumerator nextObject])
	{
		NSString *filename = [aResource lastPathComponent];
        NSString *uploadPath = [remoteDesignDirectoryPath stringByAppendingPathComponent:filename];
        [self uploadContentsOfURL:aResource toPath:uploadPath];
        // TODO: Append banner CSS and graphical text to the main.css file
	}
}

- (void)_uploadMainCSSAndGraphicalText:(NSURL *)mainCSSFileURL remoteDesignDirectoryPath:(NSString *)remoteDesignDirectoryPath
{
    NSMutableString *mainCSS = [NSMutableString stringWithContentsOfURL:mainCSSFileURL];
    
    // Add on CSS for each block
    NSDictionary *graphicalTextBlocks = [self graphicalTextBlocks];
    NSEnumerator *textBlocksEnumerator = [graphicalTextBlocks keyEnumerator];
    NSString *aGraphicalTextID;
    while (aGraphicalTextID = [textBlocksEnumerator nextObject])
    {
        KTHTMLTextBlock *aTextBlock = [graphicalTextBlocks objectForKey:aGraphicalTextID];
        KTMediaFile *aGraphicalText = [[aTextBlock graphicalTextMedia] file];
        
        NSString *path = [[NSBundle mainBundle] overridingPathForResource:@"imageReplacementEntry" ofType:@"txt"];
        OBASSERT(path);
        
        NSMutableString *CSS = [NSMutableString stringWithContentsOfFile:path usedEncoding:NULL error:NULL];
        if (CSS)
        {
            [CSS replace:@"_UNIQUEID_" with:aGraphicalTextID];
            [CSS replace:@"_WIDTH_" with:[NSString stringWithFormat:@"%i", [aGraphicalText integerForKey:@"width"]]];
            [CSS replace:@"_HEIGHT_" with:[NSString stringWithFormat:@"%i", [aGraphicalText integerForKey:@"height"]]];
            
            NSString *baseMediaPath = [[aGraphicalText defaultUpload] pathRelativeToSite];
            NSString *mediaPath = [@".." stringByAppendingPathComponent:baseMediaPath];
            [CSS replace:@"_URL_" with:mediaPath];
            
            [mainCSS appendString:CSS];
        }
        else
        {
            NSLog(@"Unable to read in image replacement CSS from %@", path);
        }
    }
    
    
    // Upload the CSS
    NSData *mainCSSData = [[mainCSS unicodeNormalizedString] dataUsingEncoding:NSUTF8StringEncoding
                                                          allowLossyConversion:YES];
    [self uploadData:mainCSSData toPath:[remoteDesignDirectoryPath stringByAppendingPathComponent:@"main.css"]];
}

#pragma mark -
#pragma mark Media

/*  Adds the media file to the upload queue (if it's not already in it)
 */
- (void)uploadMediaIfNeeded:(KTMediaFileUpload *)media
{
    if (![self onlyPublishChanges] || [media boolForKey:@"isStale"])
    {
        if (![myUploadedMedia containsObject:media])    // Don't bother if it's already in the queue
        {
            NSString *sourcePath = [[media valueForKey:@"file"] currentPath];
            NSString *uploadPath = [[self baseRemotePath] stringByAppendingPathComponent:[media pathRelativeToSite]];
            if (sourcePath && uploadPath)
            {
                [self uploadContentsOfURL:[NSURL fileURLWithPath:sourcePath] toPath:uploadPath];            
                
                // Record that we're uploading the object
                [myUploadedMedia addObject:media];
            }
        }
    }
}

/*  Upload the media if needed
 */
- (void)HTMLParser:(KTHTMLParser *)parser didParseMediaFile:(KTMediaFile *)mediaFile upload:(KTMediaFileUpload *)upload;	
{
   [self uploadMediaIfNeeded:upload];
}

#pragma mark -
#pragma mark Resources

- (void)uploadResourceIfNeeded:(NSURL *)resourceURL
{
    resourceURL = [resourceURL absoluteURL];    // Ensures hashing and -isEqual: work right
    
    if (![myUploadedResources containsObject:resourceURL])
    {
        NSString *resourcesDirectoryName = [[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultResourcesPath"];
        NSString *resourcesDirectoryPath = [[self baseRemotePath] stringByAppendingPathComponent:resourcesDirectoryName];
        NSString *resourceRemotePath = [resourcesDirectoryPath stringByAppendingPathComponent:[resourceURL lastPathComponent]];
        
        [self uploadContentsOfURL:resourceURL toPath:resourceRemotePath];
        
        [myUploadedResources addObject:resourceURL];
    }
}

- (void)HTMLParser:(KTHTMLParser *)parser didEncounterResourceFile:(NSURL *)resourceURL
{
	OBPRECONDITION(resourceURL);
    [self uploadResourceIfNeeded:resourceURL];
}

#pragma mark -
#pragma mark Uploading Support

/*	Use these methods instead of asking the connection directly. They will handle creating the appropriate directories and
 *  delete the existing file first if needed.
 *  // TODO: Set permissions
 */
- (CKTransferRecord *)uploadContentsOfURL:(NSURL *)localURL toPath:(NSString *)remotePath
{
	OBPRECONDITION(localURL);
    OBPRECONDITION([localURL isFileURL]);
    OBPRECONDITION(remotePath);
    
    
    if ([[[self documentInfo] hostProperties] boolForKey:@"deletePagesWhenPublishing"])
	{
		[[self connection] deleteFile:remotePath];
	}
	
    [self createDirectory:[remotePath stringByDeletingLastPathComponent]];
	CKTransferRecord *result = [[self connection] uploadFile:[localURL path] toFile:remotePath checkRemoteExistence:NO delegate:nil];
    [CKTransferRecord mergeRecord:result withRoot:[self rootTransferRecord]];
    return result;
    
}

- (CKTransferRecord *)uploadData:(NSData *)data toPath:(NSString *)remotePath
{
	OBPRECONDITION(data);
    OBPRECONDITION(remotePath);
  
    
    if ([[[self documentInfo] hostProperties] boolForKey:@"deletePagesWhenPublishing"])
	{
		[[self connection] deleteFile:remotePath];
	}
    
	[self createDirectory:[remotePath stringByDeletingLastPathComponent]];
    CKTransferRecord *result = [[self connection] uploadFromData:data toFile:remotePath checkRemoteExistence:NO delegate:nil];
    [CKTransferRecord mergeRecord:result withRoot:[self rootTransferRecord]];
    return result;
}

/*  Creates the specified directory including any parent directories that haven't already been queued for creation.
 *  Returns a CKTransferRecord used to represent the directory during publishing.
 */
- (CKTransferRecord *)createDirectory:(NSString *)remotePath
{
    OBPRECONDITION(remotePath);
    
    
    CKTransferRecord *root = [self rootTransferRecord];
    if ([[root path] isEqualToString:remotePath]) return root;
    
    
    // Ensure the parent directory is created first
    NSString *parentDirectoryPath = [remotePath stringByDeletingLastPathComponent];
    CKTransferRecord *parent = [self createDirectory:parentDirectoryPath];
    
    
    // Create the directory if it hasn't been already
    CKTransferRecord *result = nil;
    int i;
    for (i = 0; i < [[parent contents] count]; i++)
    {
        CKTransferRecord *aRecord = [[parent contents] objectAtIndex:i];
        if ([[aRecord path] isEqualToString:remotePath])
        {
            result = aRecord;
            break;
        }
    }
    
    if (!result)
    {
        [[self connection] createDirectory:remotePath];
        result = [CKTransferRecord recordWithName:[remotePath lastPathComponent] size:0];
        [parent addContent:result];
    }
    
    return result;
}

/*  Create the root record if needed
 */
- (CKTransferRecord *)rootTransferRecord
{
    if (!_rootTransferRecord)
    {
        _rootTransferRecord = [[CKTransferRecord rootRecordWithPath:[self baseRemotePath]] retain];
    }
    
    return _rootTransferRecord;
}

@end
