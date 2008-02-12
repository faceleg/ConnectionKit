//
//  NSApplication+KTExtensions.m
//  KTComponents
//
//  Created by Dan Wood on 9/26/05.
//  Copyright (c) 2005 Biophony LLC. All rights reserved.
//

#import "NSApplication+Karelia.h"
#import "KT.h"

@implementation NSApplication ( KTExtensions )

+ (NSString *)applicationName
{
	return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
}

@end
