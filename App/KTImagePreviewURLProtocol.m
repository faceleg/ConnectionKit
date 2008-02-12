//
//  KTImagePreviewURLProtocol.m
//  Marvel
//
//  Created by Mike on 04/10/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTImagePreviewURLProtocol.h"

#import <QuartzCore/QuartzCore.h>


@implementation KTImagePreviewURLProtocol

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[NSURLProtocol registerClass:[self class]];
	[pool release];
}

/*	We can only handle svximage:// requests
 */
+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
	NSString *scheme = [[request URL] scheme];
	return ([scheme isEqualToString:@"svximage"]);
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
	return request;
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)aRequest toRequest:(NSURLRequest *)bRequest
{
	// We don't care the main URL, just the query since that contains the media ID
	NSDictionary *queryA = [[[aRequest URL] query] queryParameters];
	NSDictionary *queryB = [[[bRequest URL] query] queryParameters];
	return [queryA isEqualToDictionary:queryB];
}

- (void)startLoading
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	
	// Figure out what we're going to be loading
	NSURL *URL = [[self request] URL];
	NSURL *mediaURL = [[[NSURL alloc] initWithScheme:@"file" host:[URL host] path:[URL path]] autorelease];
	
	
	
	// Send the initial URL response
	NSString *mimeType = [NSString MIMETypeForUTI:[NSString UTIForFileAtPath:[mediaURL path]]];
	
	NSURLResponse *response = [[NSURLResponse alloc] initWithURL:URL
														MIMEType:mimeType
										   expectedContentLength:-1
												textEncodingName:nil];
	
	[[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
	[response release];
	
	
	
	// Load up the raw media data
	NSData *result = [NSData dataWithContentsOfURL:mediaURL];
	
	
	
	// If the request is to resize an image then do so
	NSDictionary *query = [[URL query] queryParameters];
	
	NSString *scaleString = [query objectForKey:@"scale"];
	NSString *aspectRatioString = [query objectForKey:@"aspectratio"];
	
	if (result && (scaleString || aspectRatioString))
	{
		CIImage *sourceImage = [[CIImage alloc] initWithData:result];
		
		// Figure out the scale and aspect ratio to use. Fallback to 1.0 if none is specified.
		float scale = 1.0;
		if (scaleString) {
			scale = [scaleString floatValue];
		}
		if (scale <= 0.0) {
			scale = 1.0;
		}
		
		float aspectRatio = 1.0;
		if (aspectRatioString) {
			aspectRatio = [aspectRatioString floatValue];
		}
		
		// Work out what the size the finished image should be
		CGSize sourceImageSize = [sourceImage extent].size;
		float finalImageWidth = roundf(scale * sourceImageSize.width);
		float finalImageHeight = roundf(scale * sourceImageSize.height);
		CIVector *finalImageRect = [CIVector vectorWithX:0.0 Y:0.0 Z:finalImageWidth W:finalImageHeight];
		
		// The image must be clamped, scaled and then cropped.
		CIFilter *affineClampFilter =
			[CIFilter filterWithName:@"CIAffineClamp"
					   keysAndValues:@"inputImage", sourceImage,
									 @"inputTransform", [NSAffineTransform transform], nil];
					   
		CIFilter *scaleFilter =
			[CIFilter filterWithName:@"CILanczosScaleTransform"
					   keysAndValues:@"inputImage", [affineClampFilter valueForKey:@"outputImage"],
									 @"inputScale", [NSNumber numberWithFloat:scale],
									 @"inputAspectRatio", [NSNumber numberWithFloat:aspectRatio], nil];
		
		CIFilter *cropFilter =
			[CIFilter filterWithName:@"CICrop"
					   keysAndValues:@"inputImage", [scaleFilter valueForKey:@"outputImage"],
									 @"inputRectangle", finalImageRect, nil];
				
// TODO: Get the appropriate representation for the user's settings
		CIImage *scaledImage = [cropFilter valueForKey:@"outputImage"];
		result = [[scaledImage bitmap] representationUsingType:NSJPEGFileType properties:nil];
		
		[sourceImage release];
	}
	
	
	
	// Emboss with "placeholder" text if desired
	if ([query objectForKey:@"placeholder"])
	{
		NSImage *image = [[NSImage alloc] initWithData:result];
		[image embossPlaceholder];
		result = [[image bitmap] representationUsingType:NSPNGFileType properties:nil];
		[image release];
	}
	
	
	if (result)
	{
		[[self client] URLProtocol:self didLoadData:result];
		[[self client] URLProtocolDidFinishLoading:self];
	}
	else
	{
		[[self client] URLProtocol:self didFailWithError:nil];
	}
	
	
	
	[pool release];
}

- (void)stopLoading
{

}

@end
