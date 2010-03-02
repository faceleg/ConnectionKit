//
//  NSImage+KTApplication.h
//  Marvel
//
//  Created by Dan Wood on 5/10/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "CIImage+Karelia.h"


@class KTImageScalingSettings, KTMedia;


@interface NSImage ( KTApplication )

- (NSImage *)imageWithCompositedAddBadge;

- (NSBitmapImageRep *)bitmapByScalingWithBehavior:(KTImageScalingSettings *)settings;

+ (float)preferredJPEGQuality;

- (NSData *)faviconRepresentation;

/*! returns UTI but also checks alpha */
- (NSString *)preferredFormatUTI;

- (NSData *)preferredRepresentation;
- (NSData *)preferredRepresentationWithOriginalMedia:(KTMedia *)parentMedia;

// assumes kFitWithinRect, NSImageAlignCenter
- (NSImage *)imageWithMaxPixels:(int)aPixels;

// assumes kFitWithinRect, NSImageAlignCenter
- (NSImage *)imageWithMaxWidth:(int)aWidth height:(int)aHeight;

// assumes NSImageAlignCenter
- (NSImage *)imageWithMaxWidth:(int)aWidth height:(int)aHeight behavior:(CIScalingBehavior)aBehavior;

- (NSImage *)imageWithMaxWidth:(int)aWidth 
						height:(int)aHeight 
					  behavior:(CIScalingBehavior)aBehavior 
					 alignment:(NSImageAlignment)anAlignment;

- (NSData *)representationForMIMEType:(NSString *)aMimeType;
- (NSData *)representationForUTI:(NSString *)aUTI;
// Also see +[NSBitmapImageRep typeForUTI:]


#pragma mark Specific representations

- (NSData *)PNGRepresentation;
- (NSData *)PNGRepresentationWithOriginalMedia:(KTMedia *)parentMedia;

- (NSData *)JPEGRepresentationWithCompressionFactor:(float)aQuality;
- (NSData *)JPEGRepresentationWithCompressionFactor:(float)aQuality
                                      originalMedia:(KTMedia *)parentMedia;

- (NSData *)faviconRepresentation;


@end
