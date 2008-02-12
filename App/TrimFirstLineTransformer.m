//
//  TrimFirstLineTransformer.m
//  KTComponents
//
//  Created by Dan Wood on 2/21/06.
//  Copyright 2006 Biophony LLC. All rights reserved.
//

#import "TrimFirstLineTransformer.h"


@implementation TrimFirstLineTransformer

+ (Class)transformedValueClass { return [NSString class]; }
+ (BOOL)allowsReverseTransformation { return YES; }		// it's the reverse translation we care about!

- (id)transformedValue:(id)value;
{
	return value;		// the value doesn't need trimming, only the UI does.
}

/*!	Reverse -- just trim it this way before it's put into the UI
*/
- (id)reverseTransformedValue:(id)value;
{
	if ([value respondsToSelector:@selector(trimFirstLine)])
	{
		return [value trimFirstLine];
	}
	return value;
}

@end
