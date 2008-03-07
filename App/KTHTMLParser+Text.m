//
//  KTHTMLParser+Text.m
//  Marvel
//
//  Created by Mike on 05/03/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTHTMLParser+Private.h"

#import "KTMediaContainer.h"
#import "KTAbstractMediaFile.h"
#import "ContinueReadingLinkTextBlock.h"

#import "NSString+Karelia.h"


@implementation KTHTMLParser (Text)

#pragma mark -
#pragma mark Standard Text Block

// TODO: Generate nothing when publishing
- (NSString *)textblockWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	NSString *result = @"";
	
	NSDictionary *parameters = [[self class] parametersDictionaryWithString:inRestOfTag];
	
	// To actually generate a block of text all we need is a key path
	NSString *textKeyPath = [parameters objectForKey:@"property"];
	if (textKeyPath)
	{
		// Find the right object
		id object = [parameters objectForKey:@"object"];
		if (!object) object = [self component];
		
		
		// HTML tag
		NSString *tag = [parameters objectForKey:@"tag"];
		if (tag && ![tag isKindOfClass:[NSString class]]) tag = nil;
		
		
		// Build the text block
		NSArray *flags = [[parameters objectForKey:@"flags"] componentsSeparatedByWhitespace];
		result = [self textblockForKeyPath:textKeyPath ofObject:object flags:flags HTMLTag:tag];
		if (!result) result = @"";
	}
	else
	{
		NSLog(@"textblock: usage [[textblock property:text.keyPath (flags:\"some flags\")]]");
	}
	
	return result;
}

- (NSString *)textblockForKeyPath:(NSString *)keypath ofObject:(id)object flags:(NSArray *)flags HTMLTag:(NSString *)tag
{
	// Build the text block
	KTWebViewTextBlock *textBlock = [[KTWebViewTextBlock alloc] init];
	
	[textBlock setFieldEditor:[flags containsObject:@"line"]];
	[textBlock setRichText:[flags containsObject:@"block"]];
	[textBlock setImportsGraphics:[flags containsObject:@"imageable"]];
	if (tag) [textBlock setHTMLTag:tag];
	
	[textBlock setHTMLSourceObject:object];
	[textBlock setHTMLSourceKeyPath:keypath];
	
	
	// Generate HTML
	NSString *result = [textBlock outerHTML];
	
	
	// Inform delegate
	[self didParseTextBlock:textBlock];
	[textBlock release];
	
	/*
	// Process the text according to HTML generation purpose
	if ([self HTMLGenerationPurpose] == kGeneratingQuickLookPreview)
	{
		NSScanner *scanner = [[NSScanner alloc] initWithString:text];
		NSMutableString *buffer = [[NSMutableString alloc] initWithCapacity:[text length]];
		NSString *aString;
		
		while (![scanner isAtEnd])
		{
			[scanner scanUpToString:@" src=\"" intoString:&aString];
			[buffer appendString:aString];
			if ([scanner isAtEnd]) break;
			
			[buffer appendString:@" src=\""];
			[scanner setScanLocation:([scanner scanLocation] + 6)];
			
			[scanner scanUpToString:@"\"" intoString:&aString];
			NSURL *aMediaURI = [NSURL URLWithString:aString];
			KTMediaContainer *mediaContainer = [KTMediaContainer mediaContainerForURI:aMediaURI];
			if (mediaContainer)
			{
				[buffer appendString:[[mediaContainer file] quickLookPseudoTag]];
			}
			else
			{
				[buffer appendString:aString];
			}
		}
		
		text = [NSString stringWithString:buffer];
		[buffer release];
		[scanner release];
	}
	*/
	
	
	return result;
}

#pragma mark -
#pragma mark Continue Reading Link

/*	The continue reading link is a special case as we have to replace its content upon editing
 */
 
- (NSString *)continuereadinglinkWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	NSString *result = @"";
	
	NSArray *parameters = [inRestOfTag componentsSeparatedByWhitespace];
	if (parameters && [parameters count] == 1)
	{
		ContinueReadingLinkTextBlock *textBlock = [[ContinueReadingLinkTextBlock alloc] init];
		[textBlock setFieldEditor:YES];
		[textBlock setRichText:NO];
		[textBlock setImportsGraphics:NO];
		[textBlock setHasSpanIn:NO];
		[textBlock setHTMLSourceObject:[self component]];
		[textBlock setHTMLSourceKeyPath:@"page.master.continueReadingLinkFormat"];
		[textBlock setTargetPage:[[self cache] valueForKeyPath:[parameters objectAtIndex:0]]];
		
		result = [textBlock outerHTML];
		
		[self didParseTextBlock:textBlock];
		[textBlock release];
	}
	else
	{
		NSLog(@"continuereadinglink: usage [[continuereadinglink page.keyPath]]");
	}
	
	return result;
}

@end
