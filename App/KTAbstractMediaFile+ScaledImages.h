//
//  KTAbstractMediaFile+ScaledImages.h
//  Marvel
//
//  Created by Mike on 22/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTAbstractMediaFile.h"


@class KTScaledImageProperties;


@interface KTAbstractMediaFile (ScaledImages)

- (KTScaledImageProperties *)scaledImageWithProperties:(NSDictionary *)properties;
- (NSDictionary *)canonicalImagePropertiesForProperties:(NSDictionary *)properties;

@end
