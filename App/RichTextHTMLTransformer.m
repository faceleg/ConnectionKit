//
//  RichTextHTMLTransformer.m
//  Marvel
//
//  Created by Dan Wood on Wed Jul 28 2004.
//  Copyright (c) 2004-2005 Biophony, LLC. All rights reserved.
//

/*
 PURPOSE OF THIS CLASS/CATEGORY:
 Convert Rich Text <-> simple HTML, so we can have input fields (really, NSTextViews) with rich text, but
 have their contents stored as HTML, not RTF.
 
 TAXONOMY AND RELATIONSHIP TO OTHER CLASSES:
 
 
 IMPLEMENTATION NOTES & CAUTIONS:
 x
 
 TO DO:
 x
 
 */

#import "RichTextHTMLTransformer.h"

#import "NSString+Karelia.h"
#import "NSAttributedString+Karelia.h"
#import "NSString+KTExtensions.h"

@implementation RichTextHTMLTransformer

+ (Class)transformedValueClass { return [NSData class]; }
+ (BOOL)allowsReverseTransformation { return YES; }

- (id)transformedValue:(id)value;               // value is HTML text.  Must return NSData of RTF.
{
    if (value == nil) return nil;
	
	// First make an attributed string from the HTML
	NSAttributedString *attrString = nil;
	
	// Note: we must make sure font is helvetica, not Lucida, so we can show italic.
	NSString *htmlToParse = [NSString stringWithFormat:@"<span style='font:12px Helvetica'>%@</span>", value];
	NSData *theData = [htmlToParse dataUsingEncoding:NSUnicodeStringEncoding allowLossyConversion:YES];
	
	NSDictionary *encodingDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:NSUnicodeStringEncoding], @"CharacterEncoding", nil];
	attrString = [[[NSMutableAttributedString alloc] initWithHTML:theData options:encodingDict documentAttributes:nil] autorelease];
	
	// Now convert the string to RTF data
	
	NSRange theRange = NSMakeRange(0, [attrString length]);
	NSData *result = [attrString RTFFromRange:theRange documentAttributes:nil];
	
	return result;
}

- (id)reverseTransformedValue:(id)value;        // value is NSData of RTF.  Must return HTML.
{
    if (value == nil) return nil;
	
	NSAttributedString *attrString = [[[NSAttributedString alloc] initWithRTF:value documentAttributes:nil] autorelease];
	NSString *html = [attrString boldItalicOnlySnippet];
	html = [html trim];
	return html;
}

@end
