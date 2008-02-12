//
//  KTValidateCharFormatter.m
//  KTComponents
//
//  Created by Dan Wood on 2/9/06.
//  Copyright 2006 Biophony LLC. All rights reserved.
//

#import "KTValidateCharFormatter.h"
#import "NSString+Karelia.h"

@interface KTValidateCharFormatter ( Private )
- (NSCharacterSet *)illegalCharacterSet;
- (void)setIllegalCharacterSet:(NSCharacterSet *)anIllegalCharacterSet;
@end


@implementation KTValidateCharFormatter


- (id)initWithIllegalCharacterSet:(NSCharacterSet *)aBadChars
{
	if (self = [super init])
	{
		[self setIllegalCharacterSet:aBadChars];
	}
	return self;
}

// Default, allow every character.

- (id)init
{
	return [self initWithIllegalCharacterSet:[NSCharacterSet characterSetWithRange:NSMakeRange(0,0)]];
}

- (void)dealloc
{
	[self setIllegalCharacterSet:nil];
	[super dealloc];
}


// Simply return the string

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString  **)error
{
	*obj = string;
	return YES;
}

// Return the string .. object must/should be a string.
- (NSString *)stringForObjectValue:(id)anObject
{
	if ([anObject isKindOfClass: [NSString class]])
		return anObject;
	return nil;
}

/*
 origString contains the original string, before the proposed change, and origSelRange contains the selection range to which the change is to take place. partialStringPtr contains the new string to validate and proposedSelRangePtr holds the selection range that will be used if the string is accepted or replaced. Return YES if partialStringPtr is acceptable and NO if partialStringPtr is unacceptable. Assign a new string to partialStringPtr and a new range to proposedSelRangePtr and return NO if you want to replace the string and change the selection range. If you return NO, you can also return by indirection an NSString (in error) that explains the reason why the validation failed; the delegate (if any) of the NSControl managing the cell can then respond to the failure in control:didFailToValidatePartialString:errorDescription:.
 
*/

- (BOOL)isPartialStringValid:(NSString **)partialStringPtr
	   proposedSelectedRange:(NSRangePointer)proposedSelRangePtr
			  originalString:(NSString *)origString
	   originalSelectedRange:(NSRange)origSelRange
			errorDescription:(NSString **)error
{
	BOOL result = YES;
	NSCharacterSet *charset = [self illegalCharacterSet];
	if (nil != charset)
	{
		NSString *newString = [*partialStringPtr stringByRemovingCharactersInSet:charset];
		result = [newString isEqualToString:*partialStringPtr];
		if (!result)
		{
			*partialStringPtr = newString;
			*proposedSelRangePtr = origSelRange;
		}
	}
	return result;
}

#pragma mark -
#pragma mark Accessors

- (NSCharacterSet *)illegalCharacterSet
{
    return myIllegalCharacterSet; 
}

- (void)setIllegalCharacterSet:(NSCharacterSet *)anIllegalCharacterSet
{
    [anIllegalCharacterSet retain];
    [myIllegalCharacterSet release];
    myIllegalCharacterSet = anIllegalCharacterSet;
}

@end
