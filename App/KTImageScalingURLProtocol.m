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

#import <QuartzCore/CoreImage.h>


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

- (void)_startLoadingUncached
{
    NSURL *URL = [[self request] URL];
	
	
	// Load the image from disk
    CIImage *sourceImage = [[CIImage alloc] initWithContentsOfURL:[[self request] scaledImageSourceURL]];
    if(!sourceImage)
    {
        [[self client] URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain
                                                                             code:NSURLErrorResourceUnavailable
                                                                         userInfo:nil]];
        return;
    }
    
    
    // Construct image scaling properties dictionary from the URL
    NSDictionary *URLQuery = [URL queryDictionary];
    
    NSSize scaledSize = NSSizeFromString([URLQuery objectForKey:@"size"]);
    KSImageScalingMode scalingMode = [URLQuery integerForKey:@"mode"];
    
    
    // Scale the image
    CIImage *scaledImage = [sourceImage imageByScalingToSize:CGSizeMake(scaledSize.width, scaledSize.height)
                                                        mode:scalingMode
                                                 opaqueEdges:YES];
    OBASSERT(scaledImage);
    
    
    // Sharpen if needed
    float sharpeningFactor = [URLQuery floatForKey:@"sharpen"];
    if (sharpeningFactor)
    {
        scaledImage = [scaledImage sharpenLuminanceWithFactor:sharpeningFactor];
    }
    
    
    // Ensure we have a graphics context big enough to render into
    static CGContextRef graphicsContext;
    static CIContext *coreImageContext;
    if (!graphicsContext)
    {
        CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    
        graphicsContext = CGBitmapContextCreate(NULL,
                                                640, 640,
                                                8,
                                                640 * 4,
                                                colorSpace,
                                                kCGImageAlphaPremultipliedLast);
        OBASSERT(graphicsContext);
        CGColorSpaceRelease(colorSpace);
        
        coreImageContext = [CIContext contextWithCGContext:graphicsContext // Need to cache a CI context from this too
                                                   options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:kCIContextUseSoftwareRenderer]];
        [coreImageContext retain];
    }
    
    CGRect neededContextRect = [scaledImage extent];
    size_t currentContextWidth = CGBitmapContextGetWidth(graphicsContext);
    size_t currentContextHeight = CGBitmapContextGetHeight(graphicsContext);
    
    if (currentContextWidth < neededContextRect.size.width || currentContextHeight < neededContextRect.size.height)
    {
        CGContextRelease(graphicsContext);
        
        size_t newContextWidth = MAX(currentContextWidth, (size_t)ceilf(neededContextRect.size.width));
        size_t newContextHeight = MAX(currentContextHeight, (size_t)ceilf(neededContextRect.size.height));
        CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
        
        graphicsContext = CGBitmapContextCreate(NULL,
                                                newContextWidth, newContextHeight,
                                                8,
                                                newContextWidth * 4,
                                                colorSpace,
                                                kCGImageAlphaPremultipliedLast);
        OBASSERT(graphicsContext);
        CGColorSpaceRelease(colorSpace);

        [coreImageContext release]; // Need to cache a CI context from this too
        coreImageContext = [CIContext contextWithCGContext:graphicsContext
                                                   options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:kCIContextUseSoftwareRenderer]];
        [coreImageContext retain];
    }
    
    
    // Render a CGImage
    CGImageRef finalImage = [coreImageContext createCGImage:scaledImage fromRect:neededContextRect];
    OBASSERT(finalImage);
    
    
    // Convert to data
    NSString *UTI = [URLQuery objectForKey:@"filetype"];
    OBASSERT(UTI);
    
    NSMutableData *imageData = [[NSMutableData alloc] init];
    CGImageDestinationRef imageDestination = CGImageDestinationCreateWithData((CFMutableDataRef)imageData,
                                                                              (CFStringRef)UTI,
                                                                              1,
                                                                              NULL);
    
    CGImageDestinationAddImage(imageDestination,
                               finalImage,
                               (CFDictionaryRef)[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:[NSImage preferredJPEGQuality]] forKey:(NSString *)kCGImageDestinationLossyCompressionQuality]);
    
    OBASSERT(CGImageDestinationFinalize(imageDestination));
    CFRelease(imageDestination);
    CGImageRelease(finalImage); // On Tiger the CGImage MUST be released before deallocating the CIImage!
    [sourceImage release];
    
    
    
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
    [response release];
    [imageData release];
    
	[[[self class] sharedScaledImageCache] storeCachedResponse:cachedResponse forRequest:[self request]];
    [cachedResponse release];
    
    
    // Tidy up
    [[self client] URLProtocolDidFinishLoading:self];
	
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


