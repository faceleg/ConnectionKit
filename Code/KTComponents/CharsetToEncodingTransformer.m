//
//  CharsetToEncodingTransformer.m
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

#import "CharsetToEncodingTransformer.h"
#import "NSString+KTExtensions.h"

//

@implementation CharsetToEncodingTransformer

+ (Class)transformedValueClass { return [NSNumber class]; }
+ (BOOL)allowsReverseTransformation { return YES; }

- (id)transformedValue:(id)value;	// string to number
{
    if (value == nil) return nil;

    NSStringEncoding encoding = 0;

	if ([value isKindOfClass:[NSString class]])
	{
		encoding = [value encodingFromCharset];
    }
	else
	{
        [NSException raise: NSInternalInconsistencyException
                    format: @"Value (%@) is not a string.",
			[value class]];
    }

    return [NSNumber numberWithInt: encoding];
}

- (id)reverseTransformedValue:(id)value;
{
    if (value == nil) return nil;

    NSStringEncoding encoding = 0;

    // Attempt to get a reasonable value from the
    // value object.
    if ([value respondsToSelector: @selector(intValue)]) {
		// handles NSString and NSNumber
        encoding = [value intValue];
    } else {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Value (%@) does not respond to -intValue.",
			[value class]];
    }
    NSString *result = [NSString charsetFromEncoding:encoding];
    return result;
}

@end
