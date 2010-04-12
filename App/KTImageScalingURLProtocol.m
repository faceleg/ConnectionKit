//
//  KTImageScalingURLProtocol.m
//  Marvel
//
//  Created by Mike on 02/01/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KTImageScalingURLProtocol.h"
#import "KTImageScalingSettings.h"

#import "SVImageScalingOperation.h"

#import "NSImage+KTExtensions.h"

#import "NSApplication+Karelia.h"
#import "NSError+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"

#import <QuartzCore/CoreImage.h>


NSString *KTImageScalingURLProtocolScheme = @"x-sandvox-image";


@implementation NSURL (SandvoxImage)

+ (NSURL *)sandvoxImageURLWithFileURL:(NSURL *)fileURL 
                                 size:(NSSize)size
                          scalingMode:(KSImageScalingMode)scalingMode
                           sharpening:(CGFloat)sharpening
                    compressionFactor:(CGFloat)compression
                             fileType:(NSString *)UTI;
{
    NSURL *baseURL = [[NSURL alloc] initWithScheme:KTImageScalingURLProtocolScheme
											  host:[fileURL host]
											  path:[fileURL path]];
	
	NSMutableDictionary *query = [[NSMutableDictionary alloc] init];
	
    if (!NSEqualSizes(size, NSZeroSize)) [query setObject:NSStringFromSize(size) forKey:@"size"];
	[query setObject:[NSString stringWithFormat:@"%i", scalingMode] forKey:@"mode"];
	if (UTI) [query setObject:UTI forKey:@"filetype"];
	[query setObject:[NSString stringWithFormat:@"%f", sharpening] forKey:@"sharpen"];
	[query setFloat:compression forKey:@"compression"];
	
	
	NSURL *result = [NSURL URLWithBaseURL:baseURL parameters:query];
	[query release];
	[baseURL release];
	
	return result;
}

+ (NSURL *)sandvoxImageURLWithFileURL:(NSURL *)fileURL scalingProperties:(NSDictionary *)properties;
{
	// Generate a scaled URL only if requested
	if (properties)
	{
		KTImageScalingSettings *settings = [properties objectForKey:@"scalingBehavior"];
        KSImageScalingMode mode = KSImageScalingModeAspectFit; // use most common value to avoid warning
		
        switch ([settings behavior])
		{
			case KTScaleToSize:
				mode = KSImageScalingModeAspectFit;
				break;
			case KTStretchToSize:
				mode = KSImageScalingModeFill;
				break;
			case KTCropToSize:
				mode = [settings alignment] + 11;  // +11 converts from KTMediaScalingOperation to KSImageScalingMode
				break;
			default:
				break;
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

static NSURLCache *_sharedCache;

+ (void)initialize
{
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
	
	
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
	BOOL result = NO;
	
	if ([[[request URL] scheme] isEqualToString:KTImageScalingURLProtocolScheme])
	{
		NSDictionary *query = [[request URL] queryDictionary];
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
	NSCachedURLResponse *cachedResponse = [[[self class] sharedScaledImageCache] cachedResponseForRequest:[self request]];
	NSData *imageData = [cachedResponse data];
	
	
	if (imageData)
	{
		[[self client] URLProtocol:self
                didReceiveResponse:[cachedResponse response]
                cacheStoragePolicy:NSURLCacheStorageNotAllowed];	// We'll take care of our own caching
        
        
        
        [[self client] URLProtocol:self didLoadData:[cachedResponse data]];
        [[self client] URLProtocolDidFinishLoading:self];
    }
    else
    {
        [self performSelector:@selector(_startLoadingUncached) withObject:nil afterDelay:0.0];
	}
}

- (void)stopLoading
{
	// We can't kill the protocol mid-render, but we can cancel any pending renders
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_startLoadingUncached) object:nil];
}

- (void)_startLoadingUncached
{
    // Run the scaling op
    SVImageScalingOperation *op = [[SVImageScalingOperation alloc] initWithURL:
                                   [[self request] URL]];
    [op start];
    
    
    // Return decent result
    NSData *imageData = [op result];
    if (imageData)
    {
        // Construct new cached response
        NSURLResponse *response = [op returnedResponse];
        
        [[self client] URLProtocol:self
                didReceiveResponse:response
                cacheStoragePolicy:NSURLCacheStorageNotAllowed];	// We'll take care of our own caching
        
        [[self client] URLProtocol:self didLoadData:imageData];
        
        
        
        // Cache result
        NSCachedURLResponse *cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response data:imageData];
        [response release];
        
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
    
    
    [op release];
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


