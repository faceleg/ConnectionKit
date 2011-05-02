//
//  KTScaledImageProperties.h
//  Marvel
//
//  Created by Mike on 22/01/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class KTMediaFile, KTImageScalingSettings, KTInDocumentMediaFile;
@interface KTScaledImageProperties : NSManagedObject
{
}

+ (id)connectSourceFile:(KTMediaFile *)sourceFile
				 toFile:(KTInDocumentMediaFile *)destinationFile
		 withProperties:(NSDictionary *)properties;

- (KTImageScalingSettings *)scalingBehavior;
- (void)setScalingBehavior:(KTImageScalingSettings *)scalingBehavior;

- (NSDictionary *)scalingProperties;

@end
