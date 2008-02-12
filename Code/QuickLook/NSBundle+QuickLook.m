//
//  NSBundle+QuickLook.m
//  SandvoxQuickLook
//
//  Created by Dan Wood on 11/29/07.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "NSBundle+QuickLook.h"


@implementation NSBundle ( QuickLook )

- (NSString *)version;				// specified as CFBundleShortVersionString
{
    id retVal = [self objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    return retVal;
}

- (NSString *)minimumAppVersion
{
    id retVal = [self objectForInfoDictionaryKey:@"KTMinimumAppVersion"];
    return retVal;
}

@end
