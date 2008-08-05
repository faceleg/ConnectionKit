//
//  KTSimpleScaledImageContainer.m
//  Marvel
//
//  Created by Mike on 11/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTSimpleScaledImageContainer.h"

#import "KTMediaFile+ScaledImages.h"
#import "NSManagedObject+KTExtensions.h"


@implementation KTSimpleScaledImageContainer

- (KTImageScalingSettings *)scalingBehavior
{
	return [self transientValueForKey:@"scalingBehavior" persistentArchivedDataKey:@"scalingBehaviorData"];
}

- (void)setScalingBehavior:(KTImageScalingSettings *)scalingBehavior
{
	[self setTransientValue:scalingBehavior forKey:@"scalingBehavior" persistentArchivedDataKey:@"scalingBehaviorData"];
}

- (NSDictionary *)latestProperties
{
	KTImageScalingSettings *scalingBehavior = [self scalingBehavior];
	OBASSERT(nil != scalingBehavior);
	NSMutableDictionary *result = [NSMutableDictionary dictionaryWithObject:scalingBehavior forKey:@"scalingBehavior"];
	
	id aValue = [self valueForKey:@"compression"];
	if (aValue) {
		[result setObject:aValue forKey:@"compression"];
	}
	
	aValue = [self valueForKey:@"fileType"];
	if (aValue) {
		[result setObject:aValue forKey:@"fileType"];
	}
	
	aValue = [self valueForKey:@"sharpeningFactor"];
	if (aValue) {
		[result setObject:aValue forKey:@"sharpeningFactor"];
	}
	
	return result;
}

@end
