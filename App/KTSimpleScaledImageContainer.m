//
//  KTSimpleScaledImageContainer.m
//  Marvel
//
//  Created by Mike on 11/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTSimpleScaledImageContainer.h"

#import "KTAbstractMediaFile+ScaledImages.h"


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
	NSMutableDictionary *result = [NSMutableDictionary dictionaryWithObject:[self scalingBehavior] forKey:@"scalingBehavior"];
	
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

- (void)generateMediaFile
{
	NSDictionary *properties = [self latestProperties];
	KTAbstractMediaFile *sourceFile = [[self valueForKey:@"sourceMedia"] file];
	
	KTScaledImageProperties *generatedProperties = [sourceFile scaledImageWithProperties:properties];
	[self setValue:generatedProperties forKey:@"generatedProperties"];
	[self setValue:[generatedProperties valueForKey:@"destinationFile"] forKey:@"file"];
}

@end
