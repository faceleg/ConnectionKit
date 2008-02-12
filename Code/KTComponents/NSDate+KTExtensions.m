//
//  NSDate+KTExtensions.m
//  KTComponents
//
//  Created by Dan Wood on 9/16/05.
//  Copyright (c) 2005 Biophony LLC. All rights reserved.
//

#import "NSDate+KTExtensions.h"


@implementation NSDate ( KTExtensions )


/*"     Return a short, localized description (using user preferences), or today/yesterday.
		Date is converted to CalendarDate and then it's run on that new CalendarDate.
		Kind of a kludge, but it should do the trick -- if it's even needed
"*/

- (NSString *) relativeShortDescription
{
	NSCalendarDate *calendarDate = [self dateWithCalendarFormat:nil timeZone:nil];
	return [calendarDate relativeShortDescription];
}

- (NSString *)relativeFormatWithStyle:(NSDateFormatterStyle)inStyle
{
	NSCalendarDate *calendarDate = [self dateWithCalendarFormat:nil timeZone:nil];
	return [calendarDate relativeFormatWithStyle:inStyle];
}

- (NSString *)relativeFormatWithTimeAndStyle:(NSDateFormatterStyle)inStyle;
{
	NSCalendarDate *calendarDate = [self dateWithCalendarFormat:nil timeZone:nil];
	return [calendarDate relativeFormatWithTimeAndStyle:inStyle];
}

- (NSString *)descriptionRFC822		// Sat, 07 Sep 2002 09:42:31 GMT
{
	return [self descriptionWithCalendarFormat:@"%a, %d %b %Y %H:%M:%S %z"
									  timeZone:nil
										locale:nil];
	// NOTE: We're using %z for zone, e.g. +0900 .. that's OK with 822.
}

+ (id)dateWithRFC822String:(NSString *)description
{
	// Might as well make it an NSCalendarDate
	return [NSCalendarDate dateWithString:description calendarFormat:@"%a, %d %b %Y %H:%M:%S %z"];
}


@end
