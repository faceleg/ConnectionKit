//
//  KTMediaFile+ScaledImages.h
//  Marvel
//
//  Created by Mike on 22/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTMediaFile.h"


@class KTScaledImageProperties;


@interface KTMediaFile (ScaledImages)

- (KTScaledImageProperties *)scaledImageWithProperties:(NSDictionary *)properties;
- (NSDictionary *)canonicalImagePropertiesForProperties:(NSDictionary *)properties;

@end
