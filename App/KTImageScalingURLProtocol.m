//
//  KTImageScalingURLProtocol.m
//  Marvel
//
//  Created by Mike on 02/01/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "KTImageScalingURLProtocol.h"
#import "KTImageScalingSettings.h"

#import "SVImageScalingOperation.h"
#import "SVMediaRequest.h"

#import "NSImage+KTExtensions.h"

#import "NSApplication+Karelia.h"
#import "NSError+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "KSURLUtilities.h"

#import <QuartzCore/CoreImage.h>


NSString *KTImageScalingURLProtocolScheme = @"x-sandvox-image";


@implementation NSURL (SandvoxImage)

+ (NSURL *)sandvoxImageURLWithMediaRequest:(SVMediaRequest *)request;
{
    NSSize size = NSMakeSize([[request width] floatValue], [[request height] floatValue]);
    
    return [NSURL sandvoxImageURLWithFileURL:[[request media] mediaURL]
                                        size:size
                                 scalingMode:KSImageScalingModeFill
                                  sharpening:0.0f                   // settings match SVHTMLContext,
                           compressionFactor:1.0f                   // there's got to be a better way right?
                                    fileType:[request type]];
}

+ (NSURL *)sandvoxImageURLWithFileURL:(NSURL *)fileURL 
                                 size:(NSSize)size
                          scalingMode:(KSImageScalingMode)scalingMode
                           sharpening:(CGFloat)sharpening
                    compressionFactor:(CGFloat)compression
                             fileType:(NSString *)UTI;
{
    NSDictionary *query = [self sandvoxImageParametersWithSize:size
                                                   scalingMode:scalingMode
                                                    sharpening:sharpening
                                             compressionFactor:compression
                                                      fileType:UTI];
	
	return [self sandvoxImageURLWithFileURL:fileURL queryParameters:query];
}

+ (NSURL *)sandvoxImageURLWithFileURL:(NSURL *)fileURL queryParameters:(NSDictionary *)query;
{
    OBPRECONDITION(fileURL);
    OBPRECONDITION([fileURL isFileURL]);
    
    NSString *host = [fileURL host];
    if (!host) host = @"";
    
    NSURL *baseURL = [[NSURL alloc] initWithScheme:KTImageScalingURLProtocolScheme
											  host:@""
											  path:[fileURL path]];
	
	OBASSERT(baseURL);
	
    NSURL *result = [NSURL ks_URLWithScheme:KTImageScalingURLProtocolScheme
                                       host:host
                                       path:[fileURL path]
                            queryParameters:query];
    
	[baseURL release];
	
	OBPOSTCONDITION(result);
	return result;
}

+ (NSURL *)sandvoxImageURLWithFileURL:(NSURL *)fileURL scalingProperties:(NSDictionary *)properties;
{
	// Generate a scaled URL only if requested
	if (properties)
	{
		KTImageScalingSettings *settings = [properties objectForKey:@"scalingBehavior"];
        KSImageScalingMode mode = KSImageScalingModeFill;
		
        if (settings)
        {
            switch ([settings behavior])
            {
                case KTStretchToSize:
                    mode = KSImageScalingModeFill;
                    break;
                case KTCropToSize:
                    mode = [settings alignment] + 11;  // +11 converts from KTMediaScalingOperation to KSImageScalingMode
                    break;
                default:
                    mode = KSImageScalingModeAspectFit;
                    break;
            }
        }
		
		NSURL *result = [self sandvoxImageURLWithFileURL:fileURL
                                                    size:[settings size]
                                             scalingMode:mode
                                              sharpening:[properties floatForKey:@"sharpeningFactor"]
                                       compressionFactor:[properties floatForKey:@"compressionFactor"]
                                                fileType:[properties objectForKey:@"fileType"]];
		
		return result;
	}
	else
	{
		return fileURL;	
	}
}

+ (NSDictionary *)sandvoxImageParametersWithSize:(NSSize)size
                                     scalingMode:(KSImageScalingMode)scalingMode
                                      sharpening:(CGFloat)sharpening
                               compressionFactor:(CGFloat)compression
                                        fileType:(NSString *)UTI;
{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
	
    if (!NSEqualSizes(size, NSZeroSize)) [result setObject:NSStringFromSize(size) forKey:@"size"];
	[result setObject:[NSString stringWithFormat:@"%i", scalingMode] forKey:@"mode"];
	if (UTI) [result setObject:UTI forKey:@"filetype"];
	[result setObject:[NSString stringWithFormat:@"%f", sharpening] forKey:@"sharpen"];
	[result setFloat:compression forKey:@"compression"];
    
    return result;
}

@end


#pragma mark -


@interface KTImageScalingURLProtocol ()
- (void)_startLoadingUncached;
@end


#pragma mark -


@implementation KTImageScalingURLProtocol

#pragma mark -
#pragma mark Class Methods

+ (void)load
{
	[NSURLProtocol registerClass:[KTImageScalingURLProtocol class]];
}

static NSOperationQueue *_coreImageQueue;
static NSURLCache *_sharedCache;

+ (void)initialize
{
	/*  // turning the cache off for now. System one should be good enough. #103267
    if (!_sharedCache)
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
		NSString *path = [[cacheDir stringByAppendingPathComponent:[NSApplication applicationIdentifier]]
						  stringByAppendingPathComponent:@"Media"];	// Creates Media/Cache.db
		
		_sharedCache = [[NSURLCache alloc] initWithMemoryCapacity:8388608		// 8Mb
													 diskCapacity:33554432		// 32Mb
														 diskPath:path];
		
		[pool release];
     }	
     */
	
	if (!_coreImageQueue)
    {
        _coreImageQueue = [[NSOperationQueue alloc] init];
        [_coreImageQueue setMaxConcurrentOperationCount:1]; // Core Image is already multithreaded
    }
}
+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
	BOOL result = NO;
	
	if ([[[request URL] scheme] isEqualToString:KTImageScalingURLProtocolScheme])
	{
		NSDictionary *query = [[request URL] ks_queryParameters];
		if (//[query objectForKey:@"size"] &&   // Allow there to be no size and just convert between data types
			[query objectForKey:@"mode"] &&
            [query objectForKey:@"filetype"] &&
			[query objectForKey:@"compression"] &&
			[query objectForKey:@"sharpen"])
		{
			result = YES;
		}
	}
	
	return result;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
	return request;
}

- (void)dealloc;
{
    [_operation removeObserver:self forKeyPath:@"isFinished"];
    [_operation release];
    
    [super dealloc];
}

#pragma mark -
#pragma mark Cache

+ (NSURLCache *)sharedScaledImageCache
{
	return _sharedCache;
}

#pragma mark -
#pragma mark Loading

- (void)startLoading
{
	// Is the request already cached?
	NSCachedURLResponse *cachedResponse = [self cachedResponse];
    if (!cachedResponse)
    {
        NSURLRequestCachePolicy policy = [[self request] cachePolicy];
        if (policy != NSURLRequestReloadIgnoringLocalCacheData &&
            policy != NSURLRequestReloadIgnoringLocalAndRemoteCacheData)
        {
            cachedResponse = [[NSURLCache sharedURLCache] cachedResponseForRequest:[self request]];
            if (!cachedResponse)
            {
                cachedResponse = [[[self class] sharedScaledImageCache] cachedResponseForRequest:[self request]];
            }
        }
    }
    
	NSData *imageData = [cachedResponse data];
	
	
	if (imageData)
	{
		[[self client] URLProtocol:self
                didReceiveResponse:[cachedResponse response]
                cacheStoragePolicy:NSURLCacheStorageAllowed];
        
        
        
        [[self client] URLProtocol:self didLoadData:[cachedResponse data]];
        [[self client] URLProtocolDidFinishLoading:self];
    }
    else
    {
        [self _startLoadingUncached];
	}
}

- (void)stopLoading
{
    [_operation cancel];
}

- (void)_startLoadingUncached
{
    // Run the scaling op
    _operation = [[SVImageScalingOperation alloc] initWithURL:[[self request] URL]];
    [_operation addObserver:self forKeyPath:@"isFinished" options:0 context:NULL];
    [_coreImageQueue addOperation:_operation];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(SVImageScalingOperation *)operation change:(NSDictionary *)change context:(void *)context;
{
    if ([operation isCancelled]) return;
    
    // Return decent result
    NSData *imageData = [operation result];
    if (imageData)
    {
        // Construct new cached response
        NSURLResponse *response = [operation returnedResponse];
        
        [[self client] URLProtocol:self
                didReceiveResponse:response
                cacheStoragePolicy:NSURLCacheStorageAllowed];
        
        [[self client] URLProtocol:self didLoadData:imageData];
        
        
        
        // Cache result
        NSCachedURLResponse *cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response data:imageData];
        
        [[[self class] sharedScaledImageCache] storeCachedResponse:cachedResponse forRequest:[self request]];
        [cachedResponse release];
        
        
        
        // Tidy up
        [[self client] URLProtocolDidFinishLoading:self];
    }
    else
    {
        // The URL client will crash on the main thread if we pass a nil error object
        NSError *error = nil;
        if (!error) error = [NSError errorWithDomain:NSURLErrorDomain
                                                code:NSURLErrorUnknown
                                            userInfo:nil];
        
        [[self client] URLProtocol:self didFailWithError:error];
    }
}

@end


#pragma mark -


@implementation NSURLRequest (KTImageScalingURLProtocol)

- (NSURL *)scaledImageSourceURL
{
	NSURL *result = [KTImageScalingURLProtocol propertyForKey:@"scaledImageSourceURL" inRequest:self];
	return result;
}

@end


@implementation NSMutableURLRequest (KTImageScalingURLProtocol)

- (void)setScaledImageSourceURL:(NSURL *)URL
{
	[KTImageScalingURLProtocol setProperty:URL forKey:@"scaledImageSourceURL" inRequest:self];
}

@end


