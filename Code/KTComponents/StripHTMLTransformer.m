//
//  StripHTMLTransformer.m
//  KTComponents
//
//  Created by Dan Wood on 2/12/06.
//  Copyright 2006 Biophony LLC. All rights reserved.
//

#import "StripHTMLTransformer.h"
#import "NSString+KTExtensions.h"

/*!	Strips out HTML from the value we're tracking.  When sending *back*, we escape entities so it's legal (but not styled) HTML.
*/

@implementation StripHTMLTransformer

+ (Class)transformedValueClass { return [NSString class]; }
+ (BOOL)allowsReverseTransformation { return YES; }

/*!	Transform the rich text HTML into a standard string, flattening the HTML and losing formating.
*/
- (id)transformedValue:(id)value;
{
	return [value flattenHTML];
}

/*!	Reverse -- take the UI's string, and convert back into the HTML escaped version
*/
- (id)reverseTransformedValue:(id)value;
{
	return [value escapedEntities];
}

@end
