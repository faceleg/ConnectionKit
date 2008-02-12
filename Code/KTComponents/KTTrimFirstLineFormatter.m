//
//  TrimmedStringFormatter.m
//  Amazon List
//
//  Created by Mike on 29/12/2006.
//  Copyright 2006 Karelia Software. All rights reserved.
//

#import "KTTrimFirstLineFormatter.h"

#import "NSString+KTExtensions.h"


@implementation KTTrimFirstLineFormatter

- (NSString *)stringForObjectValue:(id)anObject
{
	if (![anObject isKindOfClass:[NSString class]])
		return nil;
	
	return anObject;
}

- (BOOL)getObjectValue:(id *)anObject forString:(NSString *)string errorDescription:(NSString **)error
{
	// Trim the string to its frist line
	NSString *result = [string trimFirstLine];
	*anObject = result;
	
	return YES;
}

@end
