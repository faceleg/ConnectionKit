//
//  NSImage+KTApplication.h
//  Marvel
//
//  Created by Dan Wood on 5/10/05.
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "CIImage+Karelia.h"


@class KTImageScalingSettings;


@interface NSImage ( KTApplication )

- (NSImage *)imageWithCompositedAddBadge;

- (NSBitmapImageRep *)bitmapByScalingWithBehavior:(KTImageScalingSettings *)settings;

- (NSData *)faviconRepresentation;

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
- (NSData *)JPEGRepresentationWithCompressionFactor:(float)aQuality;
- (NSData *)faviconRepresentation;


@end
