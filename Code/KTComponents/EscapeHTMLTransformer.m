//
//  EscapeHTMLTransformer.m
//  KTComponents
//
//  Created by Dan Wood on 9/16/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "EscapeHTMLTransformer.h"
#import "NSString+KTExtensions.h"

@implementation EscapeHTMLTransformer

+ (Class)transformedValueClass { return [NSString class]; }
+ (BOOL)allowsReverseTransformation { return YES; }

/*!	Transform the escaped-entities string in the backing to something we can display
*/
- (id)transformedValue:(id)value;
{
	return [value unescapedEntities];
}

/*!	Reverse -- take the string, and convert back into the HTML escaped version
*/
- (id)reverseTransformedValue:(id)value;
{
	return [value escapedEntities];
}

@end
