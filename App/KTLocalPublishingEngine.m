//
//  KTTransferController.m
//  Marvel
//
//  Created by Terrence Talbot on 10/30/08.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import "KTLocalPublishingEngine.h"

#import "KTSite.h"
#import "KTHostProperties.h"
#import "KTMaster.h"
#import "SVPublishingDigestStorage.h"
#import "KTPage.h"
#import "SVDirectoryPublishingRecord.h"
#import "KTURLCredentialStorage.h"
#import "SVGoogleSitemapPinger.h"

#import "NSManagedObjectContext+KTExtensions.h"

#import "NSBundle+Karelia.h"
#import "KSSHA1Stream.h"
#import "NSError+Karelia.h"
#import "NSInvocation+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"

#import "KSPathUtilities.h"
#import "KSURLUtilities.h"

#import "KSInvocationOperation.h"
#import "KSThreadProxy.h"
#import "KSUtilities.h"


@interface KTLocalPublishingEngine ()

- (SVPublishingRecord *)publishingRecordForPath:(NSString *)path;
- (SVPublishingRecord *)regularFilePublishingRecordWithPath:(NSString *)path;
- (SVPublishingRecord *)updatePublishingRecordForPath:(NSString *)path
                                           SHA1Digest:(NSData *)digest
                                          contentHash:(NSData *)contentHash;

- (void)pingURL:(NSURL *)URL;

@end


@interface SVPublishingRecord ()
- (void)setSHA1Digest:(NSData *)digest;
- (void)setContentHash:(NSData *)digest;
@end


#pragma mark -


@implementation KTLocalPublishingEngine

#pragma mark Init & Dealloc

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
        
        // Cache all the known publishing records
        NSArray *records = [[site managedObjectContext]
                            fetchAllObjectsForEntityForName:@"FilePublishingRecord"
                            predicate:[NSPredicate predicateWithFormat:@"SHA1Digest != nil"]
                            error:NULL];
        
        _publishingRecordsBySHA1Digest = [[NSMutableDictionary alloc]
                                          initWithObjects:records
                                          forKeys:[records valueForKey:@"SHA1Digest"]];
        
        
        records = [[site managedObjectContext] fetchAllObjectsForEntityForName:@"PublishingRecord"
                                                                         error:NULL];
        
        _publishingRecordsByPath = [[NSDictionary alloc]
                                    initWithObjects:records
                                    forKeys:[records valueForKeyPath:@"path.lowercaseString"]];
	}
	
	return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [_publishingRecordsBySHA1Digest release];
    [_publishingRecordsByPath release];
    
    [super dealloc];
}

#pragma mark Accessors

- (BOOL)onlyPublishChanges { return _onlyPublishChanges; }

#pragma mark Connection

- (void)publishData:(NSData *)data
             toPath:(NSString *)remotePath
   cachedSHA1Digest:(NSData *)digest                // save engine the trouble of calculating itself
        contentHash:(NSData *)hash
       mediaRequest:(SVMediaRequest *)mediaRequest  // if there was one behind all this
             object:(id <SVPublishedObject>)object;
{
    if ([self isPublishingToPath:remotePath]) // if already publishing, let be
    {
        return [super publishData:data
                           toPath:remotePath
                 cachedSHA1Digest:digest
                      contentHash:hash
                     mediaRequest:mediaRequest
                           object:object];
    }
    
    
    if (mediaRequest)
    {
        // Before can publish media data, must calculate content hash
        if (!hash && ([mediaRequest width] || [mediaRequest height]))
        {
            // Hopefully we've published it before. Figure out content hash
            SVMediaRequest *sourceRequest = [mediaRequest sourceRequest];
            NSData *sourceDigest = [[self digestStorage] digestForMediaRequest:sourceRequest];
            
            if (sourceDigest)
            {
                hash = [mediaRequest contentHashWithMediaDigest:sourceDigest];
            }
            else
            {
                NSInvocation *invocation = [NSInvocation
                                            invocationWithSelector:@selector(threaded_publishMediaData:toPath:request:cachedSHA1Digest:)
                                            target:self
                                            arguments:NSARRAY(data, remotePath, mediaRequest, digest)];
                
                NSOperation *operation = [[KSInvocationOperation alloc] initWithInvocation:invocation];
                [self addOperation:operation queue:[self diskOperationQueue]];
                [operation release];
                
                return;
            }
        }
        
    
        // Background hashing failed?
        if (hash == (id)[NSNull null]) hash = nil;
        
        
        // If media with the same content hash was already published, want to publish there instead
        if (hash)
        {
            SVPublishingRecord *record = [self publishingRecordForContentHash:hash];
            if (record) remotePath = [record path];
        }
    }
    
    
    // Record digest of the data for after publishing
    if (!digest)
    {
        digest = [data ks_SHA1Digest]; // could do this on -defaultQueue, but may only be worth it for larger data
    }
    
    
    // Don't upload if the data isn't stale and we've been requested to only publish changes
	if ([self onlyPublishChanges])
    {
        SVPublishingRecord *record = [self publishingRecordForPath:remotePath];
        
        // If content hash hasn't changed, no need to publish
        if ([hash isEqualToData:[record contentHash]])
        {
            if (mediaRequest && ![digest isEqualToData:[record SHA1Digest]])
            {
                NSLog(@"Not publishing %@ because content hash hasn't changed, even though digest has; from %@ to %@",
                      mediaRequest,
                      [record SHA1Digest],
                      digest);
            }
            
            // Pretend we uploaded so the engine still tracks path/digest etc.
            [self didEnqueueUpload:nil toPath:remotePath cachedSHA1Digest:digest contentHash:hash object:object];
            return;
        }
        else if ([digest isEqualToData:[record SHA1Digest]])
        {
            // Pretend we uploaded so the engine still tracks path/digest etc.
            [self didEnqueueUpload:nil toPath:remotePath cachedSHA1Digest:digest contentHash:hash object:object];
            
            // Length might not have been filled in before
            NSNumber *length = [NSNumber numberWithUnsignedLongLong:[data length]];
            if (![[record length] isEqualToNumber:length]) [record setLength:length];
            
            return;
        }
    }
    
    
    return [super publishData:data
                       toPath:remotePath
             cachedSHA1Digest:digest
                  contentHash:hash
                 mediaRequest:mediaRequest
                       object:object];
}

- (void)publishContentsOfURL:(NSURL *)localURL
                      toPath:(NSString *)remotePath
            cachedSHA1Digest:(NSData *)digest  // save engine the trouble of calculating itself
                      object:(id <SVPublishedObject>)object;
{
    if (![self isPublishingToPath:remotePath])  // if already publishing, let be
    {
        // Hash if not already known
        if (!digest)
        {
            NSInvocation *invocation = [NSInvocation
                                        invocationWithSelector:@selector(threaded_publishContentsOfURL:toPath:object:)
                                        target:self];
            [invocation setArgument:&localURL atIndex:2];
            [invocation setArgument:&remotePath atIndex:3];
            [invocation setArgument:&object atIndex:4];
            
            NSOperation *operation = [[KSInvocationOperation alloc] initWithInvocation:invocation];
            [self addOperation:operation queue:[self diskOperationQueue]];
            [operation release];
            
            return;
        }
        
        
        // Compare digests to know if it's worth publishing. Look up remote hash first to save us reading in the local file if possible
        if ([self onlyPublishChanges])
        {
            SVPublishingRecord *record = [self publishingRecordForPath:remotePath];
            NSData *publishedDigest = [record SHA1Digest];
            if ([digest isEqualToData:publishedDigest])
            {
                // Pretend we uploaded so the engine still tracks path/digest etc.
                [self didEnqueueUpload:nil toPath:remotePath cachedSHA1Digest:digest contentHash:nil object:object];
                return;
            }
        }
    }
     
    
    [super publishContentsOfURL:localURL toPath:remotePath cachedSHA1Digest:digest object:object];
}

- (void)threaded_publishContentsOfURL:(NSURL *)localURL toPath:(NSString *)remotePath object:object;
{
    // Could be done more efficiently by not loading the entire file at once
    NSError *error;
    NSData *data = [[NSData alloc] initWithContentsOfURL:localURL
                                                 options:0
                                                   error:&error];
    
    if (data)
    {
        NSData *digest = [data ks_SHA1Digest];
        [data release];
        
        [[self ks_proxyOnThread:nil]    // WANT to wait until done, else might be queued AFTER disconnect
         publishContentsOfURL:localURL toPath:remotePath cachedSHA1Digest:digest object:object];
    }
    else
    {
        if ([localURL isFileURL])
        {
            // Hopefully the failure is because it's a directory, so we can process normally
            NSFileManager *fileManager = [[NSFileManager alloc] init];
            
            BOOL isDirectory;
            if ([fileManager fileExistsAtPath:[localURL path] isDirectory:&isDirectory] &&
                isDirectory)
            {
                [[self ks_proxyOnThread:nil]    // WANT to wait until done, else might be queued AFTER disconnect
                 publishContentsOfURL:localURL
                 toPath:remotePath
                 cachedSHA1Digest:[NSData data] // stops us trying to calculate digest again!
                 object:object];
            }
            
            [fileManager release];
        }
    }
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
             contentHash:(NSData *)contentHash
                  object:(id <SVPublishedObject>)object;
{
    if (object) [record setProperty:object forKey:@"object"];
    
    [super didEnqueueUpload:record toPath:path cachedSHA1Digest:digest contentHash:contentHash object:object];
    
    if (record)
    {
        [record setProperty:path forKey:@"path"];
        if (digest) [record setProperty:digest forKey:@"dataDigest"];
        if (contentHash)
        {
            [record setProperty:contentHash forKey:@"contentHash"];
        }
    }
    else
    {
        // Fake upload, store directly to pub records
        [self updatePublishingRecordForPath:path SHA1Digest:digest contentHash:contentHash];
    }
}

#pragma mark Media

- (void)threaded_didHashSourceOfMediaRequest:(SVMediaRequest *)request;
{
    /*  Trampoline method pretty much, to fling us back to main thread!
     */
    
    [[self ks_proxyOnThread:nil] publishMediaWithRequest:request];
}

- (NSInvocationOperation *)startHashingSourceOfMediaRequest:(SVMediaRequest *)request;
{
    SVMediaRequest *sourceRequest = [request sourceRequest];
    SVMedia *media = [sourceRequest media];
    
    NSInvocationOperation *result = [[NSInvocationOperation alloc]
                                     initWithTarget:media
                                     selector:@selector(SHA1Digest)
                                     object:nil];
    OBASSERT(result);
    
    [[self digestStorage] setHashingOperation:result
                                   forMediaRequest:sourceRequest];
    
    [self addOperation:result queue:([media mediaData] ?
                                     [self defaultQueue] :
                                     [self diskOperationQueue])];
    
    return [result autorelease];
}

- (NSString *)publishMediaWithRequest:(SVMediaRequest *)request;
{
    if ([self onlyPublishChanges] && [self status] <= KTPublishingEngineStatusGatheringMedia)
    {
        if ([request width] || [request height])
        {
            SVPublishingDigestStorage *digestStorage = [self digestStorage];
            NSData *digest = [digestStorage digestForMediaRequest:request];
            
            if (!digest)
            {
                // Figure out content hash first
                SVMediaRequest *sourceRequest = [request sourceRequest];
                NSData *sourceDigest = [digestStorage digestForMediaRequest:sourceRequest];
                
                if (!sourceDigest)
                {
                    NSInvocationOperation *hashingOp = [digestStorage
                                                        hashingOperationForMediaRequest:request];
                    
                    
                    // It might be that hashing failed, so go ahead and try to publish
                    if (hashingOp)
                    {
                        if ([hashingOp isFinished])
                        {
                            sourceDigest = [digestStorage digestForMediaRequest:sourceRequest];
                            if (!sourceDigest)
                            {
                                return [super publishMediaWithRequest:request];
                            }
                        }
                    }
                    else
                    {
                        hashingOp = [self startHashingSourceOfMediaRequest:request];
                    }
                    
                    
                    // Retry once source is hashed
                    NSOperation *op = [[NSInvocationOperation alloc]
                                       initWithTarget:self
                                       selector:@selector(threaded_didHashSourceOfMediaRequest:)
                                       object:request];
                    
                    [op addDependency:hashingOp];
                    [self addOperation:op queue:nil];
                    
                    [digestStorage addMediaRequest:request cachedDigest:nil];
                    
                    [op release];
                    return nil;
                }
                
                
                NSData *hash = [request contentHashWithMediaDigest:sourceDigest];
                if (hash)
                {
                    // Seek an existing instance of that media
                    SVPublishingRecord *record = [self publishingRecordForContentHash:hash];
                    if (record)
                    {
                        // Pretend the media was uploaded
                        NSString *result = [record path];
                        OBASSERT(result);
                        
                        NSData *digest = [record SHA1Digest];
                        [[self digestStorage] addMediaRequest:request cachedDigest:digest];
                        
                        [self didEnqueueUpload:nil
                                        toPath:result
                              cachedSHA1Digest:digest
                                   contentHash:hash
                                        object:nil];
                        
                        return result;
                    }
                }
                
                // Remove from the store to fool super
                [digestStorage removeMediaRequest:request];
            }
        }
    }
    
    return [super publishMediaWithRequest:request];
}

- (void)threaded_publishMediaData:(NSData *)data
                           toPath:(NSString *)remotePath
                          request:(SVMediaRequest *)request
                 cachedSHA1Digest:(NSData *)digest;
{
    OBPRECONDITION(data);
    OBPRECONDITION(remotePath);
    OBPRECONDITION(request);
    
    
    NSData *hash = nil;
    if ([request width] || [request height])
    {
        // Hopefully we've published it before. Figure out content hash
        NSData *sourceDigest = [[request media] SHA1Digest];
        if (sourceDigest)
        {
            hash = [request contentHashWithMediaDigest:sourceDigest];
        }
        
        // Signify a failure with NSNull so we don't get stuck in an endless loop
        if (!hash) hash = (id)[NSNull null];
    }
    
    
    // Might as well hash while we're not on the main thread
    if (!digest) digest = [data ks_SHA1Digest];
    
    
    [[self ks_proxyOnThread:nil] publishData:data
                                      toPath:remotePath
                            cachedSHA1Digest:digest
                                 contentHash:hash
                                mediaRequest:request
                                      object:nil];
}

#pragma mark Status

/*  Once publishing is fully complete, without any errors, ping google if there is a sitemap
 */
- (void)engineDidPublish:(BOOL)didPublish error:(NSError *)error
{
    if (didPublish)
    {
        // Ping google about the sitemap if there is one
        if ( nil != [(SVGoogleSitemapPinger *)[self sitemapPinger] datePublished] )
        {
            NSURL *siteURL = [[[self site] hostProperties] siteURL];
            NSURL *sitemapURL = [siteURL ks_URLByAppendingPathComponent:@"sitemap.xml.gz" isDirectory:NO];
            
            NSString *pingURLString = [[NSString alloc] initWithFormat:
                                       @"http://www.google.com/webmasters/tools/ping?sitemap=%@",
                                       [[sitemapURL absoluteString] ks_stringByAddingQueryComponentPercentEscapes]];
            
            NSURL *pingURL = [[NSURL alloc] initWithString:pingURLString];
            [pingURLString release];
            
            [self pingURL:pingURL];
            [pingURL release];
            
            self.sitemapPinger = nil;
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

#pragma mark Publishing Records

- (SVPublishingRecord *)publishingRecordForPath:(NSString *)path;
{
    return [_publishingRecordsByPath objectForKey:[path lowercaseString]];
}

- (SVPublishingRecord *)regularFilePublishingRecordWithPath:(NSString *)path;
{
    OBPRECONDITION(path);
    
    
    SVPublishingRecord *result = [self publishingRecordForPath:path];
    if (![result isRegularFile])
    {
        NSArray *pathComponents = [path pathComponents];
        
        // Create intermediate directories
        SVPublishingRecord *aRecord = [[[self site] hostProperties] rootPublishingRecord];
        for (int i = 0; i < [pathComponents count] - 1; i++)
        {
            NSString *aPathComponent = [pathComponents objectAtIndex:i];        
            SVDirectoryPublishingRecord *parentRecord = (SVDirectoryPublishingRecord *)aRecord;
            aRecord = [parentRecord directoryPublishingRecordWithFilename:aPathComponent];
        }
        
        
        // Create final record
        NSString *filename = [pathComponents lastObject];
        SVDirectoryPublishingRecord *parentRecord = (SVDirectoryPublishingRecord *)aRecord;
        aRecord = [parentRecord regularFilePublishingRecordWithFilename:filename];
        
        
        // Finish up
        result = aRecord;
    }
    
    return result;
}

- (SVPublishingRecord *)updatePublishingRecordForPath:(NSString *)path
                                           SHA1Digest:(NSData *)digest
                                          contentHash:(NSData *)contentHash;
{
    SVPublishingRecord *record = [self regularFilePublishingRecordWithPath:path];
    
    NSData *oldDigest = [record SHA1Digest];
    
    // If the data hasn't changed, but the content hash is going to nil, actually want to keep existing content hash because something else is relying on it
    if ([digest isEqualToData:oldDigest])
    {
        if (contentHash)
        {
            [self setContentHash:contentHash forPublishingRecord:record];
        }
    }
    else
    {
        [self setContentHash:contentHash forPublishingRecord:record];
        
        if (oldDigest) [_publishingRecordsBySHA1Digest removeObjectForKey:oldDigest];
        [record setSHA1Digest:digest];
        [_publishingRecordsBySHA1Digest setObject:record forKey:digest];
    }
    
    return record;
}

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
        SVPublishingRecord *record = [self updatePublishingRecordForPath:path
                                 SHA1Digest:[transferRecord propertyForKey:@"dataDigest"]
                                contentHash:[transferRecord propertyForKey:@"contentHash"]];
        
        [record setLength:[NSNumber numberWithUnsignedLongLong:[transferRecord size]]];
    }
    
    
    // Mark when the object corresponding to the file was published
    id <SVPublishedObject> object = [transferRecord propertyForKey:@"object"];
    
    if ([self status] > KTPublishingEngineStatusNotStarted &&
        [self status] < KTPublishingEngineStatusFinished)
    {
        [object setDatePublished:[NSDate date]];
    }
}

// FIXME: This has a lot in common with super's implementation
- (NSString *)pathForFileWithSHA1Digest:(NSData *)digest;
{
    OBPRECONDITION(digest);
    
    NSString *result = [[self digestStorage] pathForFileWithDigest:digest];
    
    if (!result)
    {
        SVPublishingRecord *publishingRecord = [_publishingRecordsBySHA1Digest objectForKey:digest];
        
        NSString *publishedPath = [publishingRecord path];
        if (publishedPath)
        {
            // The record's path is for the published site. Correct to account for current pub location
            
            KTHostProperties *hostProperties = [[self site] hostProperties];
            NSString *base = [[hostProperties documentRoot]
                              stringByAppendingPathComponent:[hostProperties subfolder]];
            
            NSString *relativePath = [publishedPath ks_pathRelativeToDirectory:base];
            result = [[self baseRemotePath] stringByAppendingPathComponent:relativePath];
        }
    }
    
    return result;
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
