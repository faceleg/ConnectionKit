//
//  KTDesign+ScaledImages.m
//  Marvel
//
//  Created by Terrence Talbot on 12/20/07.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTDesign.h"


@implementation KTDesign ( ScaledImages )

#pragma mark -
#pragma mark Media Uses

+ (NSMutableDictionary *)_defaultMediaUses
{
	// we make the dictionary mutable so that we can add image types to it at runtime
	static NSMutableDictionary *sImageTypes = nil;
	if ( nil == sImageTypes )
	{
		NSString *imageTypesPath = [[NSBundle bundleForClass:[self class]] overridingPathForResource:@"KTScaledImageTypes" ofType:@"plist"];
		sImageTypes = [[NSMutableDictionary alloc] initWithContentsOfFile:imageTypesPath];
	}
	return sImageTypes;
}

/*	This is just a cover that hides the mutable nature of the dictionary
 */
+ (NSDictionary *)defaultMediaUses;
{
	return [self _defaultMediaUses];
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

+ (void)setInfo:(NSDictionary *)aTypeInfoDictionary forMediaUse:(NSString *)anImageName;
{
	[[self _defaultMediaUses] setValue:aTypeInfoDictionary forKey:anImageName];
}

@end
