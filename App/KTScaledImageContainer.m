//
//  KTScaledImageContainer.m
//  Marvel
//
//  Created by Mike on 12/12/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTScaledImageContainer.h"

#import "KTMediaFile+ScaledImages.h"
#import "KTScaledImageProperties.h"


@interface KTScaledImageContainer (Private)
- (BOOL)validateScalingSettings:(NSError **)error;
@end


@implementation KTScaledImageContainer

#pragma mark -
#pragma mark Scaling Settings

/*	When a ScaledImageContainer is first created it has no MediaFile attached. When this method is called
 *	for the first time we create a MediaFile. After that, we regularly check to see if the MediaFile nees updating.
 */
- (KTMediaFile *)file
{
	KTMediaFile *result = [super file];
	
	if (!mediaFileIsGenerating)
	{
		// If the settings have changed, or we have no media file, generate one.
		BOOL fileNeedsGenerating = YES;
		
		if (result)
		{
			KTScaledImageProperties *oldPropertiesObject = [self valueForKey:@"generatedProperties"];
			KTMediaFile *sourceFile = [oldPropertiesObject valueForKey:@"sourceFile"];
			
			NSDictionary *newProperties = [sourceFile canonicalImagePropertiesForProperties:[self latestProperties]];
			NSDictionary *oldProperties = [oldPropertiesObject dictionaryWithValuesForKeys:[newProperties allKeys]];
			
			if ([newProperties isEqualToDictionary:oldProperties]) {
				fileNeedsGenerating = NO;
			}
		}
		
		
		if (fileNeedsGenerating)
		{
			mediaFileIsGenerating = YES;
			[self generateMediaFile];
			mediaFileIsGenerating = NO;
			result = [super file];
		}
	}
	
	return result;
}

- (NSDictionary *)latestProperties
{
	[self subclassResponsibility:_cmd];
	return nil;
}

- (void)generateMediaFile
{
	[self subclassResponsibility:_cmd];
}

@end
