//
//  SVImageScalingOperation.m
//  Sandvox
//
//  Created by Mike on 12/04/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVImageScalingOperation.h"
#import "KSReadImageForWebOperation.h"
#import "KSWriteImageDataOperation.h"

#import "KTImageScalingSettings.h"
#import "KTImageScalingURLProtocol.h"
#import "SVMedia.h"
#import "SVMediaRequest.h"

#import "NSImage+KTExtensions.h"

#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"
#import "KSURLUtilities.h"

#import <QuartzCore/CoreImage.h>


@implementation SVImageScalingOperation

- (id)initWithMedia:(id <SVMedia>)media parameters:(NSDictionary *)params context:(CIContext *)context;
{
    [self init];
    
    _sourceMedia = [media retain];
    _parameters = [params copy];
    _context = [context retain];
    
    return self;
}

- (id)initWithURL:(NSURL *)url context:(CIContext *)context;
{
    [self init];
 
	_sourceMedia = [[SVMedia alloc] initByReferencingURL:[NSURL fileURLWithPath:[url path]
                                                                    isDirectory:NO]];
    
    _parameters = [[url ks_queryParameters] copy];
    _context = [context retain];
    
    return self;
}

- (void)dealloc
{
    [_sourceMedia release];
    [_parameters release];
    [_context release];
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
- (NSData *)_loadImageScaledToSize:(NSSize)size type:(NSString *)fileType error:(NSError **)error // Mode will be read from the URL
{
#ifdef DEBUG
    NSDate *start = [NSDate date];
#endif
    
    
    // Load the data
    NSData *data = [[_sourceMedia mediaData] retain];
    if (!data) data = [[NSData alloc] initWithContentsOfURL:[_sourceMedia mediaURL] options:0 error:error];
    if (!data) return nil;  // error pointer should be set by NSData
    
    
    // Read the image
    KSReadImageForWebOperation *readOp = [[KSReadImageForWebOperation alloc]
                                          initWithData:data
                                          width:[NSNumber numberWithFloat:size.width]
                                          height:[NSNumber numberWithFloat:size.height]];
    [data release];
    
    [readOp start]; // non-concurrent
    
    
    // Construct image scaling properties dictionary from the URL
    NSDictionary *URLQuery = _parameters;
    KSImageScalingMode scalingMode = [URLQuery integerForKey:@"mode"];
    float sharpeningFactor = [URLQuery floatForKey:@"sharpen"];
    
    
    // Render
    NSData *result = [readOp dataWithType:fileType scalingMode:scalingMode sharpening:sharpeningFactor context:_context];
    if (!result)
    {
        [readOp release];
        if (error) *error = [NSError errorWithDomain:NSURLErrorDomain
                                                code:NSURLErrorResourceUnavailable
                                            userInfo:nil];
        return nil;
    }
    
    [[result retain] autorelease];
    [readOp release];
    return result;
    
    
    
    
#ifdef DEBUG
    NSLog(@"Spent %fs doing Core Image", -[start timeIntervalSinceNow]);
#endif
    
    
    // Finish up
    return result;
}


/*  Support method to convert an image to the specified format without scaling
 */
- (NSData *)_loadImageConvertedToType:(NSString *)fileType error:(NSError **)error
{
    CGImageSourceRef imageSource;
    if ([_sourceMedia mediaData])
    {
        imageSource = CGImageSourceCreateWithData((CFDataRef)[_sourceMedia mediaData], NULL);
    }
    else
    {
        imageSource = CGImageSourceCreateWithURL((CFURLRef)[_sourceMedia mediaURL], NULL);
    }
    
    if (!imageSource)
    {
        // CGImageSource doesn't give proper error output, so assume it's because the file doesn't exist
        if (error)
        {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownError userInfo:nil];
        }
        
        return nil;
    }
        
    
    NSMutableData *result = [NSMutableData data];
    CGImageDestinationRef imageDestination = CGImageDestinationCreateWithData((CFMutableDataRef)result,
                                                                              (CFStringRef)fileType,
                                                                              1,
                                                                              NULL);
    OBASSERT(imageDestination);
    
    CGImageDestinationAddImageFromSource(imageDestination,
                                         imageSource,
                                         0,
                                         (CFDictionaryRef)[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:0.7] forKey:(NSString *)kCGImageDestinationLossyCompressionQuality]);
    
    if (!CGImageDestinationFinalize(imageDestination)) result = nil;
    CFRelease(imageDestination);
    CFRelease(imageSource);
    
    return result;
}

- (NSData *)_loadFavicon:(NSError **)error
{
    NSImage *sourceImage;
    if ([_sourceMedia mediaData])
    {
        sourceImage = [[NSImage alloc] initWithData:[_sourceMedia mediaData]];
    }
    else
    {
        sourceImage = [[NSImage alloc] initWithContentsOfURL:[_sourceMedia mediaURL]];
    }
    
    NSData *result = [sourceImage faviconRepresentation];
    [sourceImage release];
    return result;
}

- (void)main
{
    @try
    {        
        // There are three possible ways to render the result
        //  A) Scale with CoreImage
        //  B) Convert without scaling using CGImageDestination/Source
        //  C) Create a favicon representation
        NSString *UTI = [_parameters objectForKey:@"filetype"];
        OBASSERT(UTI);
        
        NSData *imageData = nil;
        NSError *error = nil;
        
        if ([UTI isEqualToString:(NSString *)kUTTypeICO])
        {
            // This is a little bit of a hack as it ignores size info, and purely creates a favicon
            imageData = [self _loadFavicon:&error];
        }
        else
        {
            NSString *size = [_parameters objectForKey:@"size"];
            if (size)
            {
                imageData = [self _loadImageScaledToSize:NSSizeFromString(size) type:UTI error:&error];
            }
            else
            {
                imageData = [self _loadImageConvertedToType:UTI error:&error];
            }
        }
        
        
        
        if (imageData)
        {
            // Construct URL response for cache etc. to use
            NSURL *url = [NSURL sandvoxImageURLWithFileURL:[_sourceMedia mediaURL]
                                           queryParameters:_parameters];
            
            _response = [[NSURLResponse alloc] initWithURL:url
                                                  MIMEType:[KSWORKSPACE ks_MIMETypeForType:UTI]
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

+ (NSData *)dataWithMediaRequest:(SVMediaRequest *)request context:(CIContext *)context response:(NSURLResponse **)response;
{
    if ([request isNativeRepresentation])
    {
        NSData *result = [[request media] mediaData];
        if (!result) result = [NSData dataWithContentsOfURL:[[request media] mediaURL]];
        
        if (response) *response = nil;
        
        return result;
    }
    else
    {
        if ([NSThread isMainThread])
        {
            NSLog(@"Evaluating scaled image data on main thread which is inadvisable as generally takes a significant amount of time");
        }
        
        SVImageScalingOperation *op = [[SVImageScalingOperation alloc]
                                       initWithMedia:[request media]
                                       parameters:[request imageScalingParameters]
                                       context:context];
        [op start];
        
        NSData *result = [[[op result] copy] autorelease];
        if (response) *response = [[[op returnedResponse] copy] autorelease];
        
        [op release];
        
        return result;
    }
}

@end
