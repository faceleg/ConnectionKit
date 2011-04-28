//
//  KTDesign+ScaledImages.m
//  Marvel
//
//  Created by Terrence Talbot on 12/20/07.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import "KTDesign.h"

#import "KTImageScalingSettings.h"

#import "NSBundle+Karelia.h"
#import "NSBundle+KTExtensions.h"
#import "NSString+Karelia.h"

#import "Debug.h"


@interface KTDesign (Deprecated)
- (NSSize)bannerSize;
@end


#pragma mark -


@implementation KTDesign (ScaledImages)

#pragma mark -
#pragma mark Defaults

+ (NSDictionary *)defaultMediaUses
{
	static NSDictionary *result = nil;
	if (!result)
	{
		NSString *imageTypesPath = [[NSBundle bundleForClass:[self class]] overridingPathForResource:@"KTScaledImageTypes" ofType:@"plist"];
		result = [[NSDictionary alloc] initWithContentsOfFile:imageTypesPath];
	}
	return result;
}

+ (NSDictionary *)infoForMediaUse:(NSString *)anImageName;
{
	NSDictionary *typeInfo = [[self defaultMediaUses] objectForKey:anImageName];
	if ( nil == typeInfo )
	{
		OFF((@"imageForKey:%@ unknown key!", anImageName));
		return nil;
	}
	return typeInfo;
}

#pragma mark -
#pragma mark Design-specific

/*	This is used by plugins (e.g. Photo and Movie) to determine what size they should fit their media into.
 *	Default values are taken from KTCachedImageTypes.plist but this allows designs to override them.
 */
- (KTImageScalingSettings *)imageScalingSettingsForUse:(NSString *)mediaUse
{
    return [[self imageScalingPropertiesForUse:mediaUse] objectForKey:@"scalingBehavior"];
}

- (NSDictionary *)imageScalingPropertiesForUse:(NSString *)mediaUse
{
	NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:2];
	
	
	// Where possible, we use the values from the design itself
	NSDictionary *allMediaInfo = [[self bundle] objectForInfoDictionaryKey:@"KTScaledImageTypes"];
	NSDictionary *mediaInfo = [allMediaInfo objectForKey:mediaUse];
	
	
	KTImageScalingSettings *scalingSettings = nil;
    if (!mediaInfo)
	{
		// Banners are a special case as we want to fallback to the -bannerSize method
		if ([mediaUse isEqualToString:@"bannerImage"])
		{
			scalingSettings = [KTImageScalingSettings cropToSize:[self bannerSize] alignment:NSImageAlignTop];
		}
		else
		{
			mediaInfo = [[self class] infoForMediaUse:mediaUse];
		}
	}
	
	
	if (!scalingSettings)
    {
        scalingSettings = [KTImageScalingSettings scalingSettingsWithDictionaryRepresentation:mediaInfo];
    }
    OBASSERT(scalingSettings);
    [result setObject:scalingSettings forKey:@"scalingBehavior"];
    
    
    
    // Now deal with UTI if available
    NSString *fileType = [mediaInfo objectForKey:@"fileType"];
    if (!fileType)
    {
        NSString *fileExtension = [mediaInfo objectForKey:@"fileExtension"];
        if (fileExtension) fileType = [[NSWorkspace sharedWorkspace] ks_typeForFilenameExtension:fileExtension];
    }
    [result setValue:fileType forKey:@"fileType"];
    
    
    
	return result;
}

@end
