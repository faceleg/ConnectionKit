//
//  KTImageScalingSettings.h
//  Marvel
//
//  Created by Mike on 09/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface KTImageScalingSettings : NSObject <NSCoding>
{
	@private
	
	KTMediaScalingOperation	myBehaviour;
	NSSize					mySize;
	float					myScaleFactor;
	NSImageAlignment		myImageAlignment;
	NSNumber				*mySharpeningFactor;
	NSNumber				*myCompression;
	NSString				*myUTI;
}

// Init
+ (id)settingsWithScaleFactor:(float)scaleFactor sharpening:(NSNumber *)sharpening;

+ (id)settingsWithBehavior:(KTMediaScalingOperation)behavior
					  size:(NSSize)size
				sharpening:(NSNumber *)sharpening;

+ (id)scalingSettingsWithDictionaryRepresentation:(NSDictionary *)dictionary;

// Accessors
- (KTMediaScalingOperation)behavior;
- (NSSize)size;
- (float)scaleFactor;
- (NSImageAlignment)alignment;
- (NSNumber *)sharpeningFactor;
- (NSString *)UTI;
- (NSNumber *)compression;

// Equality
- (BOOL)isEqual:(id)anObject;
- (BOOL)isEqualToImageScalingSettings:(KTImageScalingSettings *)settings;
- (unsigned)hash;

// Resizing
- (float)scaleFactorForImageOfSize:(NSSize)sourceSize;
- (float)aspectRatioForImageOfSize:(NSSize)sourceSize;
- (NSSize)sizeForImageOfSize:(NSSize)sourceSize;
//- (float)heightForImageOfSize:(NSSize)sourceSize;

@end
