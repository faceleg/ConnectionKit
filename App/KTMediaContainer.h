//
//  KTMedia2.h
//  Marvel
//
//  Created by Mike on 10/10/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTAbstractElement.h"


typedef enum {
	KTScaleByFactor,
	KTScaleToSize,
	KTCropToSize,
	KTStretchToSize,
} KTMediaScalingOperation;


@class KTMediaManager, KTMediaFile, KTImageScalingSettings, BDAlias;


@interface KTMediaContainer : NSManagedObject <KTExtensiblePluginPropertiesArchiving>
{
}

+ (KTMediaContainer *)mediaContainerForURI:(NSURL *)mediaURI;
+ (NSSet *)mediaContainerIdentifiersInHTML:(NSString *)HTML;
+ (NSString *)mediaContainerIdentifierForURI:(NSURL *)mediaURI;

// Accessors
- (KTMediaManager *)mediaManager;
- (NSString *)identifier;
- (NSURL *)URIRepresentation;

- (KTMediaFile *)file;

- (BDAlias *)sourceAlias;
- (void)setSourceAlias:(BDAlias *)alias;	// Only the media manager should do this

// Scaled images
- (KTMediaContainer *)scaledImageWithProperties:(NSDictionary *)properties;
									 
- (KTMediaContainer *)imageWithScaleFactor:(float)scaleFactor;
- (KTMediaContainer *)imageToFitSize:(NSSize)size;
- (KTMediaContainer *)imageCroppedToSize:(NSSize)size alignment:(NSImageAlignment)alignment;
- (KTMediaContainer *)imageStretchedToSize:(NSSize)size;

- (KTMediaContainer *)imageWithScalingSettingsNamed:(NSString *)settingsName
										  forPlugin:(KTAbstractElement *)plugin;

@end