//
//  ContainerIsEmptyTransformer.m
//  Marvel
//
//  Created by Dan Wood on 11/12/04.
//  Copyright 2004 Biophony, LLC. All rights reserved.
//

/*
PURPOSE OF THIS CLASS/CATEGORY:
	Simple transformer for general use in UIs.  Returns YES when the given object is empty, e.g. an empty string, an empty array, etc.

TAXONOMY AND RELATIONSHIP TO OTHER CLASSES:
	x

IMPLEMENTATION NOTES & CAUTIONS:
	x

TO DO:
	x

 */

#import "ContainerIsEmptyTransformer.h"

@implementation ContainerIsEmptyTransformer

+ (Class)transformedValueClass;
{
    return [NSNumber class];
}

+ (BOOL)allowsReverseTransformation;
{
    return NO;
}

- (id)transformedValue:(id)value;
{
    int count = 0;
    if (value == nil)
	{
		return [NSNumber numberWithBool:YES];
	}

    // Attempt to get a reasonable value from the
    // value object.
    if ([value respondsToSelector: @selector(count)]) {
        // handles NSArray, NSDictionary, NSIndexSet, NSSet, etc.
        count = [((NSArray *)value) count];
	} else if ([value respondsToSelector: @selector(length)]) {
		// handles NSAttributedString, NSString, NSData, etc.
		count = [((NSString *)value) length];
	} else if ([value respondsToSelector: @selector(intValue)]) {
		// handles NSNumber...
		count = [((NSString *)value) intValue];
	} else {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Value (%@) does not respond to -count or -length or intValue.",
            [value class]];
    }

    return [NSNumber numberWithBool: (count == 0)];
}

@end
