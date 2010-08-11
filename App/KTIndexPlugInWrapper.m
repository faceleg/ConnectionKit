//
//  KTIndexPluginWrapper.m
//  Marvel
//
//  Created by Mike on 14/02/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTIndexPlugInWrapper.h"
#import "KT.h"
#import "NSBundle+Karelia.h"

#import "Registration.h"

@implementation KTIndexPlugInWrapper

+ (void)load
{
	//[self registerPluginClass:[self class] forFileExtension:kKTIndexExtension];
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
