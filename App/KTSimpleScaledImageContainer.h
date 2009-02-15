//
//  KTSimpleScaledImageContainer.h
//  Marvel
//
//  Created by Mike on 11/01/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTScaledImageContainer.h"


@interface KTSimpleScaledImageContainer : KTScaledImageContainer {

}

- (KTImageScalingSettings *)scalingBehavior;
- (void)setScalingBehavior:(KTImageScalingSettings *)scalingBehavior;

@end
