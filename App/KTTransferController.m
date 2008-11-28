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
#import "KTDocumentInfo.h"
#import "KTMediaFileUpload.h"
#import "KTMediaFile.h"
#import "KTPage.h"

#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSThread+Karelia.h"

#import "KSPlugin.h"
#import "KSThreadProxy.h"
#import "KSUtilities.h"

#import "Debug.h"
#import "Registration.h"


@interface KTTransferController (Private)
- (void)uploadPage:(KTAbstractPage *)page;
- (void)uploadMedia:(KTMediaFileUpload *)media;
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
	}
	
	return self;
}

- (void)dealloc
{
	[myDocumentInfo release];
	OBASSERT(!myConnection);	// TODO: Gracefully close connection
    [myUploadedMedia release];
	
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
    
    NSString *password = nil;
    NSString *hostName = [hostProperties valueForKey:@"hostName"];
    NSString *userName = [hostProperties valueForKey:@"userName"];
    NSString *protocol = [hostProperties valueForKey:@"protocol"];
    
    NSNumber *port = [hostProperties valueForKey:@"port"];
    
    NSError *err = nil;
    
    if (hostName &&
        userName &&
        ![userName isEqualToString:@""] &&
        ![hostName isEqualToString:@""] &&
        !([hostName hasSuffix:@"idisk.mac.com"] && [protocol isEqualToString:@".Mac"]) &&   // WebDAV to idisk should take this branch and get password
        !([protocol isEqualToString:@"SFTP"] && [hostProperties boolForKey:@"usePublicKey"]))
    {
        [[EMKeychainProxy sharedProxy] setLogsErrors:YES];
        EMInternetKeychainItem *keychainItem = [[EMKeychainProxy sharedProxy] internetKeychainItemForServer:hostName
                                                                                               withUsername:userName 
                                                                                                       path:nil 
                                                                                                       port:[port intValue] 
                                                                                                   protocol:[KSUtilities SecProtocolTypeForProtocol:protocol]];
        [[EMKeychainProxy sharedProxy] setLogsErrors:NO];
        if ( nil == keychainItem )
        {
            NSLog(@"warning: publisher did not find keychain item for server %@, user %@", hostName, userName);
        }
        
        password = [keychainItem password];
    }
    
    myConnection = [[CKAbstractConnection connectionWithName:protocol
                                                        host:hostName
                                                        port:port
                                                    username:userName
                                                    password:password
                                                       error:&err] retain];
    
    [myConnection setDelegate:self];
    [myConnection connect];
}

/*  Authenticate the connection
 *  // TODO: Possibly we don't need this method and could eventually rely on just the initial authentication credentials
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
        EMInternetKeychainItem *keychainItem = [[EMKeychainProxy sharedProxy] internetKeychainItemForServer:[connection host]
                                                                                               withUsername:userName 
                                                                                                       path:nil 
                                                                                                       port:[connection port] 
                                                                                                   protocol:[KSUtilities SecProtocolTypeForProtocol:protocol]];
        [[EMKeychainProxy sharedProxy] setLogsErrors:NO];
        if ( nil == keychainItem )
        {
            NSLog(@"warning: publisher did not find keychain item for server %@, user %@", [connection host], userName);
        }
        
        password = [keychainItem password];
    }
    
    
    NSURLCredential *credential = [[NSURLCredential alloc] initWithUser:userName password:password persistence:NSURLCredentialPersistenceNone];
    [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
    [credential release];
}

/*  The root directory that all content goes into
 */
- (NSString *)storagePath   // TODO: Can anyone think of a better name?
{
	KTHostProperties *hostProperties = [[self documentInfo] hostProperties];
    NSString *result = [[hostProperties valueForKey:@"docRoot"] stringByAppendingPathComponent:[hostProperties valueForKey:@"KTHostProperties"]];
    return result;
}

#pragma mark -
#pragma mark Uploading

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
	
	
	
	
	
	
	[pool release];
}

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
				[self uploadMedia:upload];
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
    NSString *fullUploadPath = [[self storagePath] stringByAppendingPathComponent:uploadPath];
	if (fullUploadPath)
    {
		[[self connection] uploadFromData:pageData toFile:fullUploadPath];
		// TODO: Create directories, set permissions etc.
	}


	// TODO: Ask the delegate for any extra resource files


	// Generate and publish RSS feed if needed
	if ([page isKindOfClass:[KTPage class]] && [page boolForKey:@"collectionSyndicate"] && [(KTPage *)page collectionCanSyndicate])
	{
		NSString *RSSString = [(KTPage *)page RSSFeedWithParserDelegate:self];
		if (RSSString)
		{			
			// Now that we have page contents in unicode, clean up to the desired character encoding.
			// MAYBE DO THIS TOO IF WE USE SOMETHING OTHER THAN UTF8
			// rssString = [rssString stringByEscapingCharactersOutOfCharset:[aPage valueForKeyPath:@"master.charset"]];		
			// FIXME: If we specify UTF8 here, won't that get us in trouble?  Should we use other encodings, like of site?
			NSData *RSSData = [RSSString dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
			OBASSERT(RSSData);
			
			NSString *RSSFilename = [[NSUserDefaults standardUserDefaults] objectForKey:@"RSSFileName"];
			NSString *RSSUploadPath = [[fullUploadPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:RSSFilename];
			[[self connection] uploadFromData:RSSData toFile:RSSUploadPath];
		}
	}
}

#pragma mark media

/*  Adds the media file to the upload queue (if it's not already in it)
 */
- (void)uploadMedia:(KTMediaFileUpload *)media
{
    if (![myUploadedMedia containsObject:media])    // Don't bother if it's already in the queue
    {
        NSString *sourcePath = [media valueForKeyPath:@"file.currentPath"];
        NSString *uploadPath = [[self storagePath] stringByAppendingPathComponent:[media pathRelativeToSite]];
        if (sourcePath && uploadPath)
        {
            [[self connection] uploadFile:sourcePath toFile:uploadPath];
            // TODO: Create directories, set permissions etc.
            
            
            // Record that we're uploading the object
            [myUploadedMedia addObject:media];
        }
    }
}

/*  Upload the media if needed
 */
- (void)HTMLParser:(KTHTMLParser *)parser didParseMediaFile:(KTMediaFile *)mediaFile upload:(KTMediaFileUpload *)upload;	
{
   if (![self onlyPublishChanges] || [upload boolForKey:@"isStale"])
   {
       [self uploadMedia:upload];
   }
}

#pragma mark -
#pragma mark Old API

- (id)initWithAssociatedDocument:(KTDocument *)aDocument where:(int)aWhere;
{
	ISDEPRECATEDAPI;
	RAISE_EXCEPTION(@"Old API Exception", @"you need to intercept this and rewrite it", nil);
	return nil;
}
- (void)uploadStaleAssets
{
	ISDEPRECATEDAPI;
	RAISE_EXCEPTION(@"Old API Exception", @"you need to intercept this and rewrite it", nil);
}
- (void)uploadEverything
{
	ISDEPRECATEDAPI;
	RAISE_EXCEPTION(@"Old API Exception", @"you need to intercept this and rewrite it", nil);
}
- (void)uploadEverythingToSuggestedPath:(NSString *)aSuggestedPath;
{
	ISDEPRECATEDAPI;
	RAISE_EXCEPTION(@"Old API Exception", @"you need to intercept this and rewrite it", nil);
}
- (void)terminateConnection
{
	ISDEPRECATEDAPI;
	RAISE_EXCEPTION(@"Old API Exception", @"you need to intercept this and rewrite it", nil);
}



@end
