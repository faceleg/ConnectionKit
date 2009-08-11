//
//  KTScaledImageContainer.m
//  Marvel
//
//  Created by Mike on 12/12/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "KTScaledImageContainer.h"
#import "KTMediaManager.h"
#import "KTScaledImageProperties.h"

#import "KTDocument.h"

#import "NSManagedObject+KTExtensions.h"
#import "NSObject+Karelia.h"

#import "Debug.h"


@interface KTScaledImageContainer ()
+ (BOOL)_fileNeedsGenerating:(NSDictionary *)newProperties :(NSDictionary *)oldProperties;
- (BOOL)validateScalingSettings:(NSError **)error;
@end


@implementation KTScaledImageContainer

#pragma mark -
#pragma mark Scaling Settings

/*	When a ScaledImageContainer is first created it has no MediaFile attached. When this method is called
 *	for the first time we create a MediaFile. After that, we regularly check to see if the MediaFile needs updating.
 */
- (KTMediaFile *)X_file
{
	KTMediaFile *result = [super file];
	
	if (![self isDeleted] &&                        // One or more of these
        [self managedObjectContext] &&              // should fail during
        [self checkIfFileNeedsGenerating] &&        // object deletion.
        [[self mediaManager] scaledImageContainersShouldGenerateMediaFiles]) // Generating during saves will infinite loop on Tiger
	{                                                                                        
		if (result)                                                                             
		{
			if ([self fileNeedsRegenerating])
            {
                // If the file needs re-generating, we just set it to nil so that the next access will do the work
                [self setCheckIfFileNeedsGenerating:NO];
                [self setValue:nil forKey:@"file"];
                [self setCheckIfFileNeedsGenerating:YES];
            }
        }
        else
        {
            // Quite simply, we have no media file so it must be generated.
            result = [self generateMediaFile];
            if (result)
            {
                [self setCheckIfFileNeedsGenerating:NO];
                [self setValue:result forKey:@"file"];
                [self setCheckIfFileNeedsGenerating:YES];
            }
        }
    }
    
    return result;
}

- (KTMediaFile *)sourceMediaFile
{
    KTMediaFile *result = [[self valueForKey:@"sourceMedia"] sourceMediaFile];
    if (!result) result = [super sourceMediaFile];
    return result;
}

- (NSDictionary *)latestProperties
{
	SUBCLASSMUSTIMPLEMENT;
	return nil;
}

- (KTMediaFile *)generateMediaFile
{
	KTMediaFile *result = nil;
    return result;
}

#pragma mark -
#pragma mark Needs Regenerating

- (BOOL)checkIfFileNeedsGenerating { return !myDontCheckIfFileNeedsRegenerating; }

- (void)setCheckIfFileNeedsGenerating:(BOOL)flag { myDontCheckIfFileNeedsRegenerating = !flag; }

/*  Assumes we already have a file
 */
- (BOOL)fileNeedsRegenerating
{
    return NO;
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
    if (sharpening1 < (sharpening2 - 0.05) || sharpening1 > (sharpening2 + 0.05))
    {
        return YES;
    }
    
    
    return NO;
}

@end
