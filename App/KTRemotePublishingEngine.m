//
//  KTTransferController.m
//  Marvel
//
//  Created by Terrence Talbot on 10/30/08.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTRemotePublishingEngine.h"

#import "KTAbstractPage+Internal.h"
#import "KTDesign.h"
#import "KTDocumentInfo.h"
#import "KTHostProperties.h"
#import "KTMaster+Internal.h"
#import "KTPage.h"

#import "NSManagedObjectContext+KTExtensions.h"

#import "NSBundle+Karelia.h"
#import "NSError+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"

#import "KSUtilities.h"


@interface KTRemotePublishingEngine (Private)
- (void)pingURL:(NSURL *)URL;
@end


#pragma mark -


@implementation KTRemotePublishingEngine

#pragma mark -
#pragma mark Init & Dealloc

- (id)initWithSite:(KTDocumentInfo *)site onlyPublishChanges:(BOOL)publishChanges;
{
	OBPRECONDITION(site);
    
    KTHostProperties *hostProperties = [site hostProperties];
    NSString *docRoot = [hostProperties valueForKey:@"docRoot"];
    NSString *subfolder = [hostProperties valueForKey:@"subFolder"];
    
    if (self = [super initWithSite:site documentRootPath:docRoot subfolderPath:subfolder])
	{
		_onlyPublishChanges = publishChanges;
        
        // These notifications are used to mark objects non-stale
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(transferRecordDidFinish:)
                                                     name:CKTransferRecordTransferDidFinishNotification
                                                   object:nil];
	}
	
	return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
	[super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (BOOL)onlyPublishChanges { return _onlyPublishChanges; }

#pragma mark -
#pragma mark Connection

- (id <CKConnection>)createConnection
{
    KTHostProperties *hostProperties = [[self site] hostProperties];
    
    NSString *hostName = [hostProperties valueForKey:@"hostName"];
    NSString *protocol = [hostProperties valueForKey:@"protocol"];
    
    NSNumber *port = [hostProperties valueForKey:@"port"];
    
    id <CKConnection> result = [[CKConnectionRegistry sharedConnectionRegistry] connectionWithName:protocol
                                                                                              host:hostName
                                                                                              port:port];
    
    return result;
}

/*  Use the password we have stored in the keychain corresponding to the challenge's protection space
 *  and the host properties' username.
 *  If the password cannot be retrieved, fail with an error saying why
 */
- (void)connection:(id <CKConnection>)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
{
    if ([challenge previousFailureCount] > 0)
    {
        [[challenge sender] cancelAuthenticationChallenge:challenge];
        
        NSError *error = [NSError errorWithDomain:KTPublishingEngineErrorDomain
											 code:KTPublishingEngineErrorAuthenticationFailed
							 localizedDescription:NSLocalizedString(@"Authentication failed.", @"Publishing engine authentication error")
					  localizedRecoverySuggestion:NSLocalizedString(@"Please run the Host Setup Assistant again to test your host setup.", @"Publishing engine authentication error")
								  underlyingError:[challenge error]];
        
		[self failWithError:error];
        return;
    }
    
    
    KTHostProperties *hostProperties = [[self site] hostProperties];
    NSString *userName = [hostProperties valueForKey:@"userName"];
    
    NSURLCredential *credential = [[[NSURLCredentialStorage sharedCredentialStorage]
                                    credentialsForProtectionSpace:[challenge protectionSpace]]
                                   objectForKey:userName];
    
    if (credential && [credential hasPassword] && [credential password])    // Fetching it from the keychain might fail
    {
        [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
    }
    else
    {
        [[challenge sender] cancelAuthenticationChallenge:challenge];
        
		NSError *error = [NSError errorWithDomain:KTPublishingEngineErrorDomain
											 code:KTPublishingEngineErrorNoCredentialForAuthentication
							 localizedDescription:NSLocalizedString(@"Username or password could not be found.", @"Publishing engine authentication error")
					  localizedRecoverySuggestion:NSLocalizedString(@"Please run the Host Setup Assistant and re-enter your host's login credentials.", @"Publishing engine authentication error")
								  underlyingError:[challenge error]];
        
		[self failWithError:error];
    }
}

/*  Once publishing is fully complete, without any errors, ping google if there is a sitemap
 */
- (void)connection:(id <CKConnection>)con didDisconnectFromHost:(NSString *)host;
{
    // Ping google about the sitemap if there is one
    if ([[self site] boolForKey:@"generateGoogleSitemap"])
    {
        NSURL *siteURL = [[[self site] hostProperties] siteURL];
        NSURL *sitemapURL = [siteURL URLByAppendingPathComponent:@"sitemap.xml.gz" isDirectory:NO];
        
        NSString *pingURLString = [[NSString alloc] initWithFormat:
                                   @"http://www.google.com/webmasters/tools/ping?sitemap=%@",
                                   [[sitemapURL absoluteString] URLQueryEncodedString:YES]];
        
        NSURL *pingURL = [[NSURL alloc] initWithString:pingURLString];
        [pingURLString release];
        
        [self pingURL:pingURL];
        [pingURL release];
        
    }
    
    
    // Record the app version published with
    NSManagedObject *hostProperties = [[self site] hostProperties];
    [hostProperties setValue:[[NSBundle mainBundle] marketingVersion] forKey:@"publishedAppVersion"];
    [hostProperties setValue:[[NSBundle mainBundle] buildVersion] forKey:@"publishedAppBuildVersion"];
    
        
    [super connection:con didDisconnectFromHost:host];
}

/*	Supplement the default behaviour by also deleting any existing file first if the user requests it.
 */
- (CKTransferRecord *)uploadContentsOfURL:(NSURL *)localURL toPath:(NSString *)remotePath
{
	OBPRECONDITION(localURL);
    OBPRECONDITION([localURL isFileURL]);
    OBPRECONDITION(remotePath);
    
    
    if ([[[self site] hostProperties] boolForKey:@"deletePagesWhenPublishing"])
	{
		[[self connection] deleteFile:remotePath];
	}
	
    return [super uploadContentsOfURL:localURL toPath:remotePath];
    
}

- (CKTransferRecord *)uploadData:(NSData *)data toPath:(NSString *)remotePath
{
	OBPRECONDITION(data);
    OBPRECONDITION(remotePath);
    
    
    if ([[[self site] hostProperties] boolForKey:@"deletePagesWhenPublishing"])
	{
		[[self connection] deleteFile:remotePath];
	}
    
	return [super uploadData:data toPath:remotePath];
}

#pragma mark -
#pragma mark Content Generation

/*  Called when a transfer we are observing finishes. Mark its corresponding object non-stale and
 *  stop observation.
 */
- (void)transferRecordDidFinish:(NSNotification *)notification
{
    CKTransferRecord *transferRecord = [notification object];
    id object = [transferRecord propertyForKey:@"object"];
    
    if (object &&
        ![transferRecord error] &&
        [self hasStarted] &&
        ![self hasFinished] &&
        [transferRecord root] == [self rootTransferRecord])
    {
        if ([object isKindOfClass:[KTPage class]])
        {
            // Record the digest and path of the page published
            [object setPublishedDataDigest:[transferRecord propertyForKey:@"dataDigest"]];
            [object setPublishedPath:[transferRecord propertyForKey:@"path"]];
        }
        else if ([object isKindOfClass:[KTDesign class]])
        {
            // Record the version of the design published
            NSManagedObjectContext *moc = [[self site] managedObjectContext];
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@", [(KTDesign *)object identifier]];
            
            NSArray *designPublishingInfo = [moc objectsWithEntityName:@"DesignPublishingInfo"
                                                             predicate:predicate
                                                                 error:NULL];
            
            [designPublishingInfo setValue:[(KTDesign *)object marketingVersion] forKey:@"versionLastPublished"];
        }
        else if ([object isKindOfClass:[KTMaster class]])
        {
            [object setPublishedDesignCSSDigest:[transferRecord propertyForKey:@"dataDigest"]];
        }
        else
        {
            // It's probably a simple media object. Mark it non-stale.
            [object setBool:NO forKey:@"isStale"];
        }
    }
}

- (BOOL)shouldUploadHTML:(NSString *)HTML
                encoding:(NSStringEncoding)encoding
                 forPage:(KTAbstractPage *)page
                  toPath:(NSString *)uploadPath
                  digest:(NSData **)outDigest;
{
    // Generate data digest. It has to ignore the app version string
    NSString *versionString = [NSString stringWithFormat:@"<meta name=\"generator\" content=\"%@\" />",
                               [[self site] appNameVersion]];
    NSString *versionFreeHTML = [HTML stringByReplacing:versionString with:@"<meta name=\"generator\" content=\"Sandvox\" />"];
    NSData *digest = [[versionFreeHTML dataUsingEncoding:encoding allowLossyConversion:YES] sha1Digest];
    
    
	
	// Don't upload if the page isn't stale and we've been requested to only publish changes
	if ([self onlyPublishChanges])
    {
        NSData *publishedDataDigest = [page publishedDataDigest];
        NSString *publishedPath = [page publishedPath];
        
        if (publishedDataDigest &&
            (!publishedPath || [uploadPath isEqualToString:publishedPath]) &&   // 1.5.1 and earlier didn't store -publishedPath
            [publishedDataDigest isEqualToData:digest])
        {
            return NO;
        }
    }
    
    
    *outDigest = digest;
    return YES;
}

- (void)uploadMediaIfNeeded:(KTMediaFileUpload *)media
{
    if (![self onlyPublishChanges] || [media boolForKey:@"isStale"])
    {
        [super uploadMediaIfNeeded:media];
    }
}

/*  This method gets called once all pages, media and designs have been processed. If there's nothing
 *  queued to be uploaded at this point, we want to cancel and tell the user
 */
- (void)uploadResourceFiles
{
    if ([self onlyPublishChanges] && [[[self baseTransferRecord] contents] count] == 0)
    {
        // Fake an error that the window controller will use to close itself
        NSError *error = [NSError errorWithDomain:KTPublishingEngineErrorDomain
											 code:KTPublishingEngineNothingToPublish
										 userInfo:nil];
        [self failWithError:error];
    }
    else
    {
        [super uploadResourceFiles];
    }
}

#pragma mark -
#pragma mark Design

- (void)uploadDesignIfNeeded
{
    // When publishing changes, only upload the design if its published version is different to the current one
    KTMaster *master = [[[self site] root] master];
    KTDesign *design = [master design];
    if (![self onlyPublishChanges] ||
        ![[design marketingVersion] isEqualToString:[master valueForKeyPath:@"designPublishingInfo.versionLastPublished"]])
    {
        [super uploadDesignIfNeeded];
    }
}

- (BOOL)shouldUploadMainCSSData:(NSData *)mainCSSData digest:(NSData **)outDigest
{
    BOOL result = YES;
    
    NSData *digest = [mainCSSData sha1Digest];
    NSData *publishedDigest = [[[[self site] root] master] publishedDesignCSSDigest];
    
    if ([self onlyPublishChanges] && publishedDigest && [publishedDigest isEqualToData:digest])
    {
        result = NO;
    }
    else if (digest)
    {
        *outDigest = digest;
    }
    
    return result;
}

#pragma mark -
#pragma mark Ping

/*  Sends a GET request to the URL but does nothing with the result.
 */
- (void)pingURL:(NSURL *)URL
{
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:URL
                                                  cachePolicy:NSURLRequestReloadIgnoringCacheData
                                              timeoutInterval:10.0];
    
    [NSURLConnection connectionWithRequest:request delegate:nil];
    [request release];
}

@end
