//
//  NSMutableDictionary+KTExtensions.m
//  KTComponents
//
//  Copyright (c) 2004-2005 Biophony LLC. All rights reserved.
//

#import "NSMutableDictionary+KTExtensions.h"

#import "Debug.h"
#import "KT.h"

@implementation NSMutableDictionary ( KTExtentions )

/*
- (NSCalendarDate *)calendarDateForKey:(NSString *)aKey
{
    NSString *dateString = [self valueForKey:aKey];
    
    if ( nil != dateString ) {
        NSCalendarDate *result = [NSCalendarDate dateWithString:dateString
                                                 calendarFormat:kKTDefaultCalendarFormat];
        if ( nil == result ) {
            LOG((@"unable to convert dateString to date: %@", dateString));
        }
        return result;
    }
    else {
        return nil;
    }
}

- (void)setCalendarDate:(NSCalendarDate *)aCalendarDate forKey:(NSString *)aKey
{
    NSString *dateString = [aCalendarDate descriptionWithCalendarFormat:kKTDefaultCalendarFormat];
    [self setValue:dateString forKey:aKey];
}
*/

@end


