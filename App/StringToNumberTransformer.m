//
//  StringToNumberTransformer.m
//  KTComponents
//
//  Created by Dan Wood on 6/27/06.
//  Copyright 2006 Karelia Software. All rights reserved.
//

// This is for a NUMBER in the UI and a STRING in the model.  I'm using it only for the case where I have a slider
// (which binds to a number) and I want to store it as a string representation


#import "StringToNumberTransformer.h"

@implementation StringToNumberTransformer

+ (Class)transformedValueClass { return [NSNumber class]; }
+ (BOOL)allowsReverseTransformation { return YES; }

- (id)transformedValue:(id)value;
{
	if ([value respondsToSelector:@selector(floatValue)])
	{
		return [NSNumber numberWithFloat:[value floatValue]];
	}
	return nil;
}

/*!	Reverse -- create a string from an NSNumber.  Hard wire in a 4 digit precision, arbitrarily
*/
- (id)reverseTransformedValue:(id)value;
{
	if ([value respondsToSelector:@selector(floatValue)])
	{
		return [NSString stringWithFormat:@"%.4f", [value floatValue]];
	}
	return nil;
}


@end
