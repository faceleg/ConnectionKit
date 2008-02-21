//
//  KTScaledImageProperties.h
//  Marvel
//
//  Created by Mike on 22/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class KTAbstractMediaFile, KTImageScalingSettings, KTInDocumentMediaFile;
@interface KTScaledImageProperties : NSManagedObject
{
}

+ (id)connectSourceFile:(KTAbstractMediaFile *)sourceFile
				 toFile:(KTInDocumentMediaFile *)destinationFile
		 withProperties:(NSDictionary *)properties;

- (KTImageScalingSettings *)scalingBehavior;
- (void)setScalingBehavior:(KTImageScalingSettings *)scalingBehavior;

@end
