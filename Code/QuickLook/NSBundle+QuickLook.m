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

/*	Specify the file as a path relative to the bundle.
 *	Converts it to a pseudo tag of the form <!svxdata bundle:identifier/file>
 */
- (NSString *)quicklookDataForFile:(NSString *)file;
{
	NSString *result = [NSString stringWithFormat:@"<!svxdata bundle:%@/%@>",
												  [self bundleIdentifier],
												  file];
	
	return result;
}

@end
