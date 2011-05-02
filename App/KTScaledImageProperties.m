//
//  KTScaledImageProperties.m
//  Marvel
//
//  Created by Mike on 22/01/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import "KTScaledImageProperties.h"

#import "KTImageScalingSettings.h"
#import "NSManagedObject+KTExtensions.h"

@implementation KTScaledImageProperties

+ (id)connectSourceFile:(KTMediaFile *)sourceFile
				 toFile:(KTInDocumentMediaFile *)destinationFile
		 withProperties:(NSDictionary *)properties;
{
	KTScaledImageProperties *result = [NSEntityDescription insertNewObjectForEntityForName:@"ScaledImageProperties"
																	inManagedObjectContext:[sourceFile managedObjectContext]];
	
	[result setValue:[properties valueForKey:@"compression"] forKey:@"compression"];
    [result setValue:[properties valueForKey:@"scalingBehavior"] forKey:@"scalingBehavior"];
    [result setValue:[properties valueForKey:@"sharpeningFactor"] forKey:@"sharpeningFactor"];
    
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

/*  Pulls together our properties, plus the filetype to provide the standard properties dictionary.
 */
- (NSDictionary *)scalingProperties
{
    NSMutableDictionary *buffer = [[NSMutableDictionary alloc] init];
    
    [buffer setValue:[self valueForKey:@"compression"] forKey:@"compression"];
    [buffer setValue:[self valueForKey:@"scalingBehavior"] forKey:@"scalingBehavior"];
    [buffer setValue:[self valueForKey:@"sharpeningFactor"] forKey:@"sharpeningFactor"];
    [buffer setValue:[self valueForKeyPath:@"destinationFile.fileType"] forKey:@"fileType"];
    
    
    NSDictionary *result = [[buffer copy] autorelease];
    [buffer release];
    return result;
}

@end
