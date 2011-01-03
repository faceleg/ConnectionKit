//
//  NSHelpManager+KTExtensions.m
//  KTComponents
//
//  Created by Dan Wood on 4/11/07.
//  Copyright (c) 2007-2011 Karelia Software. All rights reserved.
//

#import "NSHelpManager+KTExtensions.h"


@implementation NSHelpManager ( KTExtensions )

+(BOOL)gotoHelpAnchor:(NSString *)anAnchor	// may include # for section within a page
{
	NSString *path = nil;
	NSRange whereHash = [anAnchor rangeOfString:@"#"];
	if (NSNotFound != whereHash.location)
	{
		NSString *section = [anAnchor substringFromIndex:whereHash.location + 1];
		anAnchor = [anAnchor substringToIndex:whereHash.location];
		path = [NSString stringWithFormat:@"z/%@.html#%@", anAnchor, section];
	}
	else
	{
		path = [NSString stringWithFormat:@"z/%@.html", anAnchor];	// no section
	}
	NSString *theBookName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleHelpBookName"];
	OSErr err = AHGotoPage ((CFStringRef)theBookName, (CFStringRef) path, NULL /* anchorName */); 
	return (err == noErr);
}

@end
