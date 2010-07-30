//
//  KTTransferController.m
//  Marvel
//
//  Created by Terrence Talbot on 10/30/08.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTLocalPublishingEngine.h"

#import "KTDesign.h"
#import "KTSite.h"
#import "KTHostProperties.h"
#import "KTMaster.h"
#import "KTPage.h"
#import "SVPublishingRecord.h"
#import "KTURLCredentialStorage.h"

#import "NSManagedObjectContext+KTExtensions.h"

#import "NSBundle+Karelia.h"
#import "NSData+Karelia.h"
#import "NSError+Karelia.h"
#import "NSInvocation+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"

#import "KSInvocationOperation.h"
#import "KSThreadProxy.h"
#import "KSUtilities.h"


@interface KTLocalPublishingEngine ()
- (void)pingURL:(NSURL *)URL;
@end


#pragma mark -


@implementation KTLocalPublishingEngine

#pragma mark Init & Dealloc

- (id)init;
{
    [super init];
    
    _diskAccessQueue = [[NSOperationQueue alloc] init];
    [_diskAccessQueue setMaxConcurrentOperationCount:1];
    
    return self;
}

- (id)initWithSite:(KTSite *)site onlyPublishChanges:(BOOL)publishChanges;
{
	OBPRECONDITION(site);
    
    KTHostProperties *hostProperties = [site hostProperties];
    NSString *docRoot = [hostProperties documentRoot];
    NSString *subfolder = [hostProperties subfolder];
    
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
    
    [_diskAccessQueue release];
    
	[super dealloc];
}

#pragma mark Accessors

- (BOOL)onlyPublishChanges { return _onlyPublishChanges; }

#pragma mark Connection

- (void)publishData:(NSData *)data
             toPath:(NSString *)remotePath
   cachedSHA1Digest:(NSData *)digest  // save engine the trouble of calculating itself
        contentHash:(NSData *)hash
             object:(id <SVPublishedObject>)object;
{
    // Record digest of the data for after publishing
    if (!digest) digest = [data SHA1Digest];
    
    
    // Don't upload if the page isn't stale and we've been requested to only publish changes
	if ([self onlyPublishChanges])
    {
        SVPublishingRecord *record = [[[self site] hostProperties] publishingRecordForPath:remotePath];
        
        NSData *toPublishDigest = (hash ? hash : digest);
        NSData *publishedDigest = (hash ? [record contentHash] : [record SHA1Digest]);
        
        if ([toPublishDigest isEqualToData:publishedDigest]) return;
    }
    
    
    return [super publishData:data toPath:remotePath cachedSHA1Digest:digest contentHash:hash object:object];
}

- (void)publishContentsOfURL:(NSURL *)localURL
                      toPath:(NSString *)remotePath
            cachedSHA1Digest:(NSData *)digest;
{
    // Hash if not already known
    if (!digest)
    {
        NSInvocation *invocation = [NSInvocation
                                    invocationWithSelector:@selector(threaded_publishContentsOfURL:toPath:)
                                    target:self];
        [invocation setArgument:&localURL atIndex:2];
        [invocation setArgument:&remotePath atIndex:3];
        
        NSInvocationOperation *operation = [[KSInvocationOperation alloc] initWithInvocation:invocation];
        [_diskAccessQueue addOperation:operation];
        [operation release];
        
        return;
    }
    
    
    // Compare digests to know if it's worth publishing. Look up remote hash first to save us reading in the local file if possible
    if ([self onlyPublishChanges])
    {
        SVPublishingRecord *record = [[[self site] hostProperties] publishingRecordForPath:remotePath];
        NSData *publishedDigest = [record SHA1Digest];
        if ([digest isEqualToData:publishedDigest]) return;
    }
    
    
    [super publishContentsOfURL:localURL toPath:remotePath cachedSHA1Digest:digest];
}

- (void)threaded_publishContentsOfURL:(NSURL *)localURL toPath:(NSString *)remotePath;
{
    // Could be done more efficiently by not loading the entire file at once
    NSData *data = [[NSData alloc] initWithContentsOfURL:localURL];
    NSData *digest = [data SHA1Digest];
    [data release];
    
    [[self ks_proxyOnThread:nil waitUntilDone:NO]
     publishContentsOfURL:localURL toPath:remotePath cachedSHA1Digest:digest];
}

/*	Supplement the default behaviour by also deleting any existing file first if the user requests it.
 */
- (CKTransferRecord *)willUploadToPath:(NSString *)path;
{
    OBPRECONDITION(path);
    
    CKTransferRecord *result = [super willUploadToPath:path];
    
    if ([[[self site] hostProperties] boolForKey:@"deletePagesWhenPublishing"])
	{
		[[self connection] deleteFile:path];
	}
    
    return result;
}

- (void)didEnqueueUpload:(CKTransferRecord *)record
                  toPath:(NSString *)path
        cachedSHA1Digest:(NSData *)digest
             contentHash:(NSData *)contentHash;
{
    [super didEnqueueUpload:record toPath:path cachedSHA1Digest:digest contentHash:contentHash];
    
    [record setProperty:path forKey:@"path"];
    if (digest) [record setProperty:digest forKey:@"dataDigest"];
    if (contentHash) [record setProperty:contentHash forKey:@"contentHash"];
}

#pragma mark Status

- (void)finishPublishing;
{
    // It's quite likely there's still hashing operations running. We can't disconnect till all of those those have been published.
    NSInvocationOperation *finishOp = [[NSInvocationOperation alloc]
                                       initWithTarget:self
                                       selector:@selector(reallyFinishPublishing)
                                       object:nil];
        
    for (NSOperation *anOperation in [_diskAccessQueue operations])
    {
        [finishOp addDependency:anOperation];
    }
    
    [_diskAccessQueue addOperation:finishOp];   // could go on any queue really, ideally +mainQueue
    [finishOp release];
}

- (void)reallyFinishPublishing;
{
    if (![NSThread isMainThread])
    {
        return [[self ks_proxyOnThread:nil waitUntilDone:NO] reallyFinishPublishing];
    }
    
    [super finishPublishing];
}

/*  Once publishing is fully complete, without any errors, ping google if there is a sitemap
 */
- (void)engineDidPublish:(BOOL)didPublish error:(NSError *)error
{
    if (didPublish)
    {
        // Ping google about the sitemap if there is one
        if ([[self site] boolForKey:@"generateGoogleSitemap"])
        {
            NSURL *siteURL = [[[self site] hostProperties] siteURL];
            NSURL *sitemapURL = [siteURL URLByAppendingPathComponent:@"sitemap.xml.gz" isDirectory:NO];
            
            NSString *pingURLString = [[NSString alloc] initWithFormat:
                                       @"http://www.google.com/webmasters/tools/ping?sitemap=%@",
                                       [[sitemapURL absoluteString] stringByAddingURLQueryPercentEscapes]];
            
            NSURL *pingURL = [[NSURL alloc] initWithString:pingURLString];
            [pingURLString release];
            
            [self pingURL:pingURL];
            [pingURL release];
        }
        
        
        // ping JS-Kit
        KTMaster *master = [[[self site] rootPage] master];
        if ( nil != master )
        {
            if ( [master wantsJSKit] && (nil != [master JSKitModeratorEmail]) )
            {
                NSURL *siteURL = [[[self site] hostProperties] siteURL];
                
                NSString *pingURLString = [[NSString alloc] initWithFormat:
                                           @"http://js-kit.com/api/isv/site-bind?email=%@&site=%@&confirmviaemail=%@",
                                           [[master JSKitModeratorEmail] stringByAddingPercentEscapesWithSpacesAsPlusCharacters:YES],
                                           [[siteURL absoluteString] stringByAddingPercentEscapesWithSpacesAsPlusCharacters:YES],
										   ([[NSUserDefaults standardUserDefaults] boolForKey:@"JSKitConfirmModeratorViaEmail"] ? @"YES" : @"NO")];
                
                NSURL *pingURL = [[NSURL alloc] initWithString:pingURLString];
                [pingURLString release];
                
                [self pingURL:pingURL];
                [pingURL release];
            }
        }
        
        
        // Record the app version published with
        NSManagedObject *hostProperties = [[self site] hostProperties];
        [hostProperties setValue:[[NSBundle mainBundle] marketingVersion] forKey:@"publishedAppVersion"];
        [hostProperties setValue:[[NSBundle mainBundle] buildVersion] forKey:@"publishedAppBuildVersion"];
    }
    
    
    [super engineDidPublish:didPublish error:error];
    
    
    // Case 37891: Wipe the undo stack as we don't want the user to undo back past the publishing changes
    NSUndoManager *undoManager = [[[self site] managedObjectContext] undoManager];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NSUndoManagerCheckpointNotification
                                                        object:undoManager];
    [undoManager removeAllActions];
}

#pragma mark Content Generation

/*  Called when a transfer we are observing finishes. Mark its corresponding object non-stale and
 *  stop observation.
 */
- (void)transferRecordDidFinish:(NSNotification *)notification
{
    CKTransferRecord *transferRecord = [notification object];
    
    if ([transferRecord root] != [self rootTransferRecord]) return; // it's not for us
    if ([transferRecord error]) return; // bail
    
    
    
    
    //  Update publishing records to match
    NSString *path = [transferRecord propertyForKey:@"path"];
    if (path && ![transferRecord isDirectory])
    {
        SVPublishingRecord *record = [[[self site] hostProperties] regularFilePublishingRecordWithPath:path];
        
        NSData *digest = [transferRecord propertyForKey:@"dataDigest"];
        [record setSHA1Digest:digest];
        [record setContentHash:[transferRecord propertyForKey:@"contentHash"]];
    }
    
    
    // Mark when the object corresponding to the file was published
    id <SVPublishedObject> object = [transferRecord propertyForKey:@"object"];
    
    if ([self status] > KTPublishingEngineStatusNotStarted &&
        [self status] < KTPublishingEngineStatusFinished)
    {
        [object setDatePublished:[NSDate date]];
    }
}

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
