//
//  KTIndexPlugin.m
//  Marvel
//
//  Created by Mike on 14/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTIndexPlugin.h"


@implementation KTIndexPlugin

+ (void)load
{
	[KTAppPlugin registerPluginClass:[self class] forFileExtension:@"svxIndex"];
}

- (id)defaultPluginPropertyForKey:(NSString *)key
{
	if ([key isEqualToString:@"KTIndexNavigationArrowsStyle"])
	{
		return [NSNumber numberWithInt:0];
	}
	else
	{
		return [super defaultPluginPropertyForKey:key];
	}
}

@end
