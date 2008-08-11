//
//  NSString+Publishing.m
//  Marvel
//
//  Created by Mike on 22/11/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "NSString+Publishing.h"

#import "NSString+Karelia.h"
#import "NSString-Utilities.h"

#import "Registration.h"


@implementation NSString (Publishing)

/*!	Normalizes Unicode composition of HTML.  Puts additional HTML code to indicate a trial license.  
*/
- (NSString *)stringByAdjustingHTMLForPublishing
{
	NSString *result = [self unicodeNormalizedString];
	if ((nil == gRegistrationString) || gLicenseIsBlacklisted)
	{
		NSString *sandvoxTrialFormat = NSLocalizedString(@"This page was created by a trial version of %@. (Sandvox must be purchased to publish multiple pages.)",@"Warning for a published home page; the placeholder is replaced with 'Sandvox' as a hyperlink.");
		
		NSString *sandvoxToReplace = @"<a style=\"color:blue;\" href=\"http://www.sandvox.com/\">Sandvox</a>";
		NSString *sandvoxText = [NSString stringWithFormat:sandvoxTrialFormat, sandvoxToReplace];
		NSString *endingBodyText = [NSString stringWithFormat: @"<div style=\"z-index:999; position:fixed; bottom:0; left:0; right:0; margin:10px; padding:10px; background-color:yellow; border: 2px dashed gray; color:black; text-align:center; font:150%% 'Lucida Grande', sans-serif;\">%@</div></body>", sandvoxText];
		
		result = [result stringByReplacing:@"</body>" with:endingBodyText];
	}
	return result;
}

@end


#pragma mark -


@implementation NSString (FileSizeFormatting)

+ (NSString *)formattedFileSizeWithBytes:(NSNumber *)filesize
{
	static NSString *suffix[] = { @"B", @"KB", @"MB", @"GB", @"TB", @"PB", @"EB" };
	int i, c = 7;
	long size = [filesize longValue];
	
	for ( i = 0; i < c && size >= 1024; i++ )
	{
		size = size / 1024;
	}
	
	return [NSString stringWithFormat:@"%ld %@", size, suffix[i]];
}

@end


#pragma mark -


@implementation NSString (KTPathHelp)

- (NSString *)stringByDeletingFirstPathComponent2
{
	NSString *str = self;
	if ([str hasPrefix:@"/"])
		str = [str substringFromIndex:1];
	NSMutableArray *comps = [NSMutableArray arrayWithArray:[str componentsSeparatedByString:@"/"]];
	if ([comps count] > 0) {
		[comps removeObjectAtIndex:0];
	}
	return [comps componentsJoinedByString:@"/"];
}

- (NSString *)firstPathComponent
{
	NSString *str = self;
	if ([str hasPrefix:@"/"])
		str = [str substringFromIndex:1];
	NSMutableArray *comps = [NSMutableArray arrayWithArray:[str componentsSeparatedByString:@"/"]];
	if ([comps count] > 0) {
		return [comps objectAtIndex:0];
	}
	return @"";
}

@end

