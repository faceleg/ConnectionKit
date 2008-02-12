//
//  RowHeightTransformer.m
//  Marvel
//
//  Created by Dan Wood on Wed Jul 28 2004.
//  Copyright (c) 2004-2005 Biophony, LLC. All rights reserved.
//

/*
PURPOSE OF THIS CLASS/CATEGORY:
	Used to convert a boolean (whether to have 1 or 2 rows) to a number, indicating height of the row in the outline view.
	YES -> 34, NO -> 17.
	This makes it easy to use bindings to associate the row height of the outline view with a preference.

TAXONOMY AND RELATIONSHIP TO OTHER CLASSES:
	x

IMPLEMENTATION NOTES & CAUTIONS:
	x

TO DO:
	x

 */

#import "RowHeightTransformer.h"

//

@implementation RowHeightTransformer

+ (Class)transformedValueClass { return [NSNumber class]; }
+ (BOOL)allowsReverseTransformation { return YES; }

- (id)transformedValue:(id)value;
{
    bool inputBool = NO;
    int outputHeight = 0;

    if (value == nil) return nil;

    // Attempt to get a reasonable value from the
    // value object.
    if ([value respondsToSelector: @selector(intValue)]) {
		// handles NSString and NSNumber
        inputBool = [value intValue];
    } else {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Value (%@) does not respond to -intValue.",
			[value class]];
    }

    outputHeight = inputBool ? 34 : 17;

    return [NSNumber numberWithInt: outputHeight];
}

- (id)reverseTransformedValue:(id)value;
{
    int inputHeight = 0;
    bool outputBool;

    if (value == nil) return nil;

    // Attempt to get a reasonable value from the
    // value object.
    if ([value respondsToSelector: @selector(intValue)]) {
		// handles NSString and NSNumber
        inputHeight = [value intValue];
    } else {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Value (%@) does not respond to -intValue.",
			[value class]];
    }
    // calculate "tall" boolean
    outputBool = ( inputHeight > 17);

    return [NSNumber numberWithInt:outputBool];
}

@end
