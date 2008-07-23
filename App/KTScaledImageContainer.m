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

#import "Debug.h"


@interface KTScaledImageContainer (Private)
+ (BOOL)_fileNeedsGenerating:(NSDictionary *)newProperties :(NSDictionary *)oldProperties;
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
            
            
            // Where did the media come from?
            KTMediaFile *sourceFile = [oldPropertiesObject valueForKey:@"sourceFile"];
            if (!sourceFile) sourceFile = [[self valueForKey:@"sourceMedia"] file];
            
            
            if (sourceFile)
            {
                NSDictionary *newProperties = [sourceFile canonicalImagePropertiesForProperties:[self latestProperties]];
                OBASSERT(newProperties);
                
                NSDictionary *oldProperties = [oldPropertiesObject scalingProperties];
                if (oldProperties)
                {
                    // So are the new properties different enough from the old to necessitate regeneration?
                    fileNeedsGenerating = [[self class] _fileNeedsGenerating:newProperties :oldProperties];
                }
                else
                {
                    fileNeedsGenerating = [sourceFile propertiesRequireScaling:newProperties];
                }
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

+ (BOOL)_fileNeedsGenerating:(NSDictionary *)newProperties :(NSDictionary *)oldProperties
{
    if (![[newProperties objectForKey:@"scalingBehavior"] isEqual:[oldProperties objectForKey:@"scalingBehavior"]])
    {
        return YES;
    }
    
    
    NSString *fileType = [newProperties objectForKey:@"fileType"];
    if (!fileType || ![fileType isEqualToString:[oldProperties objectForKey:@"fileType"]])
    {
        return YES;
    }
    
    
    float compression1 = [newProperties floatForKey:@"compression"];
    float compression2 = [oldProperties floatForKey:@"compression"];
    if (compression1 < (compression2 - 0.05) || compression1 > (compression2 + 0.05))
    {
        return YES;
    }
    
    
    float sharpening1 = [newProperties floatForKey:@"sharpeningFactor"];
    float sharpening2 = [oldProperties floatForKey:@"sharpeningFactor"];
    if (sharpening1 < (sharpening2 - 0.05) && sharpening1 > (sharpening2 + 0.05))
    {
        return YES;
    }
    
    
    return NO;
}

- (NSDictionary *)latestProperties
{
	SUBCLASSMUSTIMPLEMENT;
	return nil;
}

- (void)generateMediaFile
{
	KTMediaFile *sourceFile = [[self valueForKey:@"sourceMedia"] file];
    NSDictionary *canonicalProperties = [sourceFile canonicalImagePropertiesForProperties:[self latestProperties]];
	
    KTMediaFile *scaledMediaFile = sourceFile;
    if ([sourceFile propertiesRequireScaling:canonicalProperties])
    {
        KTScaledImageProperties *generatedProperties = [sourceFile scaledImageWithProperties:canonicalProperties];
        [self setValue:generatedProperties forKey:@"generatedProperties"];
        scaledMediaFile = [generatedProperties valueForKey:@"destinationFile"];
    }
    
    [self setValue:scaledMediaFile forKey:@"file"];
}

@end
