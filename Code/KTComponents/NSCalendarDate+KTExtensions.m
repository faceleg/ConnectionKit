//
//  NSCalendarDate+KTExtensions.m
//  KTComponents
//
//  Copyright (c) 2004 Biophony LLC. All rights reserved.
//


// FIXME: Use of the NSCalendarDate class is again discouraged in 10.5, but it is not deprecated yet. It may be in the next major OS release after 10.5. NSDateFormatter should be used for date formatting, and NSCalendar should be used for calendrical calculations. Where formatting differs between NSCalendarDate and NSDateFormatter (10.4-style) differ, the NSDateFormatter result will be considered to be the correct result (absent a bug being exercised). Where NSCalendar and NSCalendarDate calendrical calculations differ and the NSCalendar result is reasonable, we define its value to be the correct value. Developers should abandon hope for NSCalendarDate bug fixes.


#import "NSCalendarDate+KTExtensions.h"

#import "KT.h"
#import "KTAbstractPlugin.h"		// for the benefit of L'izedStringInKTComponents macro

@implementation NSCalendarDate ( KTExtensions )

- (BOOL) hasRelativeDayName
{
	int todayNum = [[NSCalendarDate calendarDate] dayOfCommonEra];
    int myNum = [self dayOfCommonEra];
    return (myNum == todayNum) || (myNum == (todayNum-1)) || (myNum == (todayNum+1));
}
	
/*
 NSCalendarDate: Short description plus relative dates like Today, Yesterday
  */


- (NSString *)relativeFormatWithStyle:(NSDateFormatterStyle)inStyle
{
    NSString *result;
    
    int todayNum = [[NSCalendarDate calendarDate] dayOfCommonEra];
    int myNum = [self dayOfCommonEra];
    if (myNum == todayNum)
    {
        result = NSLocalizedString(@"Today",@"Relative Date - Today");
    }
    else if (myNum == (todayNum-1))
    {
        result = NSLocalizedString(@"Yesterday",@"Relative Date - Yesterday");
    }
    else if (myNum == (todayNum+1))
    {
        result = NSLocalizedString(@"Tomorrow",@"Relative Date - Tomorrow");
    }
    else
    {
		NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
		[formatter setDateStyle:inStyle];
		[formatter setTimeStyle:NSDateFormatterNoStyle];	// no time
		
		result = [formatter stringForObjectValue:self];
	}
	return result;
}

/*"     Return a short, localized description (using user preferences), or today/yesterday.
"*/

- (NSString *) relativeShortDescription
{
	NSString *result = [self relativeFormatWithStyle:kCFDateFormatterShortStyle];
	return result;
}

- (NSString *)relativeFormatWithTimeAndStyle:(NSDateFormatterStyle)inStyle
{
    NSString *result = [self relativeFormatWithStyle:inStyle];
	if ([self hasRelativeDayName])
	{
		// Figure out time string from date
		NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
		[formatter setDateStyle:NSDateFormatterNoStyle]; // no date
		[formatter setTimeStyle:NSDateFormatterShortStyle];
		NSString *timeString = [formatter stringForObjectValue:self];
		// append time because it was yesterday/today/tomorrow
		result = [NSString stringWithFormat:NSLocalizedString(@"%@ at %@",
															  "Describes a recent time: [%@ = Yesterday/Today/Tomorrow] at [%@ = time]"), result, timeString];
	}
	return result;
}

@end
