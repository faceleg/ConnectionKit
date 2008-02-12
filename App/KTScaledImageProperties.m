//
//  KTScaledImageProperties.m
//  Marvel
//
//  Created by Mike on 22/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTScaledImageProperties.h"

#import "KTImageScalingSettings.h"


@implementation KTScaledImageProperties

+ (id)connectSourceFile:(KTAbstractMediaFile *)sourceFile
				 toFile:(KTInDocumentMediaFile *)destinationFile
		 withProperties:(NSDictionary *)properties;
{
	KTScaledImageProperties *result = [NSEntityDescription insertNewObjectForEntityForName:@"ScaledImageProperties"
																	inManagedObjectContext:[sourceFile managedObjectContext]];
	
	[result setValuesForKeysWithDictionary:properties];
	[result setValue:sourceFile forKey:@"sourceFile"];
	[result setValue:destinationFile forKey:@"destinationFile"];
	
	return result;
}

- (KTImageScalingSettings *)scalingBehavior
{
	return [self transientValueForKey:@"scalingBehavior" persistentArchivedDataKey:@"scalingBehaviorData"];
}

- (void)setScalingBehavior:(KTImageScalingSettings *)scalingBehavior
{
	[self setTransientValue:scalingBehavior forKey:@"scalingBehavior" persistentArchivedDataKey:@"scalingBehaviorData"];
}

@end
