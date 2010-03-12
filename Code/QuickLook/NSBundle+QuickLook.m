//
//  NSBundle+QuickLook.m
//  SandvoxQuickLook
//
//  Created by Dan Wood on 11/29/07.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "NSBundle+QuickLook.h"

#import "KSPlugInWrapper.h"


@implementation NSBundle (QuickLook)

/*	Supplements the default NSBundle behavior by:
 *		A) Using KSPlugInWrapper whenever possible.
 *		B) Also trying NSWorkspace
 */
+ (NSBundle *)quickLookBundleWithIdentifier:(NSString *)identifier
{
	NSBundle *result = [[KSPlugInWrapper pluginWithIdentifier:identifier] bundle];
	
	if (!result)
	{
		result = [self bundleWithIdentifier:identifier];
	}
	
	return result;
}


- (NSString *)marketingVersion;				// specified as CFBundleShortVersionString
{
    id retVal = [self objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    return retVal;
}

- (NSString *)minimumAppVersion
{
    id retVal = [self objectForInfoDictionaryKey:@"KSMinimumAppVersion"];
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
