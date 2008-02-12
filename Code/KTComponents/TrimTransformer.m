//
//  TrimTransformer.m
//  KTComponents
//
//  Created by Dan Wood on 2/21/06.
//  Copyright 2006 Biophony LLC. All rights reserved.
//

#import "TrimTransformer.h"
#import "NSString+Karelia.h"


@implementation TrimTransformer

+ (Class)transformedValueClass { return [NSString class]; }
+ (BOOL)allowsReverseTransformation { return YES; }		// no real un-trim, but returning the trimmed is fine

// Transform internal value to UI.  The internal value isn't going to need trimming, the UI is

- (id)transformedValue:(id)value;
{
	return value;
}

/*!	Reverse, input to internals -- this is really what we want for most uses.
*/
- (id)reverseTransformedValue:(id)value;
{
	if ([value respondsToSelector:@selector(trim)])
	{
		return [value trim];
	}
	return value;
}


@end
