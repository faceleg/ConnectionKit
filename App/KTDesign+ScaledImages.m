//
//  KTDesign+ScaledImages.m
//  Marvel
//
//  Created by Terrence Talbot on 12/20/07.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTDesign.h"

#import "KTImageScalingSettings.h"

#import "NSBundle+Karelia.h"
#import "NSBundle+KTExtensions.h"

#import "Debug.h"


@implementation KTDesign ( ScaledImages )

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
		TJT((@"imageForKey:%@ unknown key!", anImageName));
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
	KTImageScalingSettings *result = nil;
	
	
	// Where possible, we use the values from the design itself
	NSDictionary *allMediaInfo = [[self bundle] objectForInfoDictionaryKey:@"KTScaledImageTypes"];
	NSDictionary *mediaInfo = [allMediaInfo objectForKey:mediaUse];
	
	
	if (!mediaInfo)
	{
		// Banners are a special case as we want to fallback to the -bannerSize method
		if ([mediaUse isEqualToString:@"bannerImage"])
		{
			result = [KTImageScalingSettings cropToSize:[self bannerSize] alignment:NSImageAlignTop];
		}
		else
		{
			mediaInfo = [[self class] infoForMediaUse:mediaUse];
		}
	}
	
	
	if (!result) result = [KTImageScalingSettings scalingSettingsWithDictionaryRepresentation:mediaInfo];
	return result;
}


- (NSSize)maximumMediaSizeForUse:(NSString *)mediaUse
{
	// Pull the values out of the design bundle. They may well be nil
	NSDictionary *allMediaInfo = [[[self bundle] infoDictionary] objectForKey:@"KTScaledImageTypes"];
	NSDictionary *mediaInfo = [allMediaInfo objectForKey:mediaUse];
	
	NSNumber *maxWidth = [mediaInfo objectForKey:@"maxWidth"];
	NSNumber *maxHeight = [mediaInfo objectForKey:@"maxHeight"];
	
	// Replace nil values with the default
	if (!maxWidth)
	{
		maxWidth = [[KTDesign infoForMediaUse:mediaUse] objectForKey:@"maxWidth"];
	}
	
	if (!maxHeight)
	{
		maxHeight = [[KTDesign infoForMediaUse:mediaUse] objectForKey:@"maxHeight"];
	}
	
	NSSize result = NSMakeSize([maxWidth unsignedIntValue], [maxHeight unsignedIntValue]);
	return result;
}


@end
