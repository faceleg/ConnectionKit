//
//  SVImageScalingOperation.m
//  Sandvox
//
//  Created by Mike on 12/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVImageScalingOperation.h"

#import "KTImageScalingSettings.h"

#import "NSImage+KTExtensions.h"

#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"

#import <QuartzCore/CoreImage.h>


@implementation SVImageScalingOperation

- (id)initWithURL:(NSURL *)url;
{
    [self init];
    _sourceURL = [url copy];
    return self;
}

- (void)dealloc
{
    [_sourceURL release];
    [_result release];
    [_response release];
    
    [super dealloc];
}

#pragma mark Accessors

@synthesize result = _result;
@synthesize returnedResponse = _response;

#pragma mark Work

/*  Support method to read in an image, scale it down and then create the the specified data representation
 */
- (NSData *)_loadImageAtURL:(NSURL *)sourceURL scaledToSize:(NSSize)size type:(NSString *)fileType error:(NSError **)error // Mode will be read from the URL
{
    NSURL *URL = _sourceURL;
    
    
    // Load the image from disk
    CIImage *sourceImage = [[CIImage alloc] initWithContentsOfURL:sourceURL];
    if (!sourceImage)
    {
        if (error) *error = [NSError errorWithDomain:NSURLErrorDomain
                                                code:NSURLErrorResourceUnavailable
                                            userInfo:nil];
        return nil;
    }
    
    
    // Construct image scaling properties dictionary from the URL
    NSDictionary *URLQuery = [URL queryDictionary];
    KSImageScalingMode scalingMode = [URLQuery integerForKey:@"mode"];
    
    
    // Scale the image
    CIImage *scaledImage = [sourceImage imageByScalingToSize:CGSizeMake(size.width, size.height)
                                                        mode:scalingMode
                                                 opaqueEdges:YES];
    OBASSERT(scaledImage);
    
    
    // Sharpen if needed
    float sharpeningFactor = [URLQuery floatForKey:@"sharpen"];
    if (sharpeningFactor)
    {
        scaledImage = [scaledImage sharpenLuminanceWithFactor:sharpeningFactor];
    }
    OBASSERT(scaledImage);
    
    
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
    
    CGRect neededContextRect = [scaledImage extent];    // Clang, we assert scaledImage is non-nil above
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
	NSArray *identifiers = (NSArray *)CGImageDestinationCopyTypeIdentifiers();
	OBASSERT([identifiers containsObject:fileType]);
    [identifiers release];
	
    
    NSMutableData *result = [NSMutableData data];
    CGImageDestinationRef imageDestination = CGImageDestinationCreateWithData((CFMutableDataRef)result,
                                                                              (CFStringRef)fileType,
                                                                              1,
                                                                              NULL);
    OBASSERT(imageDestination);
    
    CGImageDestinationAddImage(imageDestination,
                               finalImage,
                               (CFDictionaryRef)[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:[NSImage preferredJPEGQuality]] forKey:(NSString *)kCGImageDestinationLossyCompressionQuality]);
    
    if (!CGImageDestinationFinalize(imageDestination)) result = nil;
    CFRelease(imageDestination);
    CGImageRelease(finalImage); // On Tiger the CGImage MUST be released before deallocating the CIImage!
    [sourceImage release];
    
    
    // Finish up
    return result;
}


/*  Support method to convert an image to the specified format without scaling
 */
- (NSData *)_loadImageAtURL:(NSURL *)URL convertToType:(NSString *)fileType error:(NSError **)error
{
    CGImageSourceRef imageSource = CGImageSourceCreateWithURL((CFURLRef)URL, NULL);
    OBASSERT(imageSource);
    
    NSMutableData *result = [NSMutableData data];
    CGImageDestinationRef imageDestination = CGImageDestinationCreateWithData((CFMutableDataRef)result,
                                                                              (CFStringRef)fileType,
                                                                              1,
                                                                              NULL);
    OBASSERT(imageDestination);
    
    CGImageDestinationAddImageFromSource(imageDestination,
                                         imageSource,
                                         0,
                                         (CFDictionaryRef)[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:[NSImage preferredJPEGQuality]] forKey:(NSString *)kCGImageDestinationLossyCompressionQuality]);
    
    if (!CGImageDestinationFinalize(imageDestination)) result = nil;
    CFRelease(imageDestination);
    CFRelease(imageSource);
    
    return result;
}

- (NSData *)_loadFaviconFromURL:(NSURL *)URL error:(NSError **)error
{
    NSImage *sourceImage = [[NSImage alloc] initWithContentsOfURL:URL];
    NSData *result = [sourceImage faviconRepresentation];
    [sourceImage release];
    return result;
}

- (void)main
{
    @try
    {
        NSURL *URL = _sourceURL;
        
        
        
        // Construct image scaling properties dictionary from the URL
        NSDictionary *URLQuery = [URL queryDictionary];
        
        NSURL *sourceURL = [[NSURL alloc] initWithScheme:@"file" host:[URL host] path:[URL path]];
        OBASSERT(sourceURL);
        
        
        
        // There are three possible ways to render the result
        //  A) Scale with CoreImage
        //  B) Convert without scaling using CGImageDestination/Source
        //  C) Create a favicon representation
        NSString *UTI = [URLQuery objectForKey:@"filetype"];
        OBASSERT(UTI);
        
        NSData *imageData = nil;    NSError *error = nil;
        if ([UTI isEqualToString:(NSString *)kUTTypeICO])
        {
            // This is a little bit of a hack as it ignores size info, and purely creates a favicon
            imageData = [self _loadFaviconFromURL:sourceURL error:&error];
        }
        else
        {
            NSString *size = [URLQuery objectForKey:@"size"];
            if (size)
            {
                imageData = [self _loadImageAtURL:sourceURL scaledToSize:NSSizeFromString(size) type:UTI error:&error];
            }
            else
            {
                imageData = [self _loadImageAtURL:sourceURL convertToType:UTI error:&error];
            }
        }
        
        
        
        if (imageData)
        {
            // Construct new cached response
            _response = [[NSURLResponse alloc] initWithURL:URL
                                                  MIMEType:[NSString MIMETypeForUTI:UTI]
                                     expectedContentLength:[imageData length]
                                          textEncodingName:nil];
            
            _result = [imageData retain];
        }
    }
    @catch (NSException *exception)
    {
        [NSApp performSelectorOnMainThread:@selector(reportException:) withObject:exception waitUntilDone:NO];
    }
}

@end
