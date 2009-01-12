//
//  KTImageScalingURLProtocol.m
//  Marvel
//
//  Created by Mike on 02/01/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KTImageScalingURLProtocol.h"

#import "NSImage+KTExtensions.h"

#import "CIImage+Karelia.h"
#import "NSApplication+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"


NSString *KTImageScalingURLProtocolScheme = @"x-sandvox-image";


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
	
	if ([[[request URL] scheme] isEqualToString:KTImageScalingURLProtocolScheme] &&
		[request scaledImageSourceURL])
	{
		NSDictionary *query = [[request URL] queryDictionary];
		if ([query objectForKey:@"size"] &&
			[query objectForKey:@"mode"] &&
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
#pragma mark Init
/*
- (id)initWithRequest:(NSURLRequest *)request cachedResponse:(NSCachedURLResponse *)cachedResponse client:(id <NSURLProtocolClient>)client
{
	
}*/

#pragma mark -
#pragma mark Loading

- (void)_startLoadingUncached
{
    NSURL *URL = [[self request] URL];
	
	
	// Construct image scaling properties dictionary from the URL
    NSDictionary *URLQuery = [URL queryDictionary];
    
    NSSize scaledSize = NSSizeFromString([URLQuery objectForKey:@"size"]);
    KSImageScalingMode scalingMode = [URLQuery integerForKey:@"mode"];
    
    
    // Scale the image
    CIImage *sourceImage = [[CIImage alloc] initWithContentsOfURL:[[self request] scaledImageSourceURL]];
    CIImage *scaledImage = [sourceImage imageByScalingToSize:CGSizeMake(scaledSize.width, scaledSize.height)
                                                        mode:scalingMode
                                                 opaqueEdges:YES];
    
    
    // Sharpen if needed
    float sharpeningFactor = [URLQuery floatForKey:@"sharpen"];
    if (sharpeningFactor)
    {
        scaledImage = [scaledImage sharpenLuminanceWithFactor:sharpeningFactor];
    }
    
    
    // Convert back to bitmap
    NSImage *finalImage = [scaledImage toNSImageBitmap];
    OBASSERT(finalImage);
    [sourceImage release];
    
    
    // Figure out the file type
    NSString *UTI = [URLQuery objectForKey:@"filetype"];
    if (!UTI) UTI = [finalImage preferredFormatUTI];
    
    
    // Convert to data
    NSData *imageData = [finalImage representationForUTI:UTI];
    OBASSERT(imageData);
    
    
    // Construct new cached response
    NSURLResponse *response = [[NSURLResponse alloc] initWithURL:URL
                                                        MIMEType:[NSString MIMETypeForUTI:UTI]
                                           expectedContentLength:[imageData length]
                                                textEncodingName:nil];
    
    [[self client] URLProtocol:self
            didReceiveResponse:response
            cacheStoragePolicy:NSURLCacheStorageNotAllowed];	// We'll take care of our own caching
    
    [[self client] URLProtocol:self didLoadData:imageData];
    
    
    // Cache result
    NSCachedURLResponse *cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response data:imageData];
	[[[self class] sharedScaledImageCache] storeCachedResponse:cachedResponse forRequest:[self request]];
    
    
    // Tidy up
    [[self client] URLProtocolDidFinishLoading:self];
	
    [cachedResponse release];
    [response release];
}

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
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_startLoadingUncached) object:nil];
    
    // Nothing we can really do, but we must implement this method
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


