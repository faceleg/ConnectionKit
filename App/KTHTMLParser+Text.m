//
//  KTHTMLParser+Text.m
//  Marvel
//
//  Created by Mike on 05/03/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTHTMLParser+Private.h"
#import "KTHTMLParserMasterCache.h"

#import "KTMediaContainer.h"
#import "KTAbstractMediaFile.h"
#import "KTPage.h"
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
		// Find the right object and key path
		id object = [parameters objectForKey:@"object"];
		if (!object)
		{
			NSArray *keyPathComponents = [textKeyPath componentsSeparatedByString:@"."];
			NSString *firstKey = [keyPathComponents objectAtIndex:0];
			object = [[self cache] overridingValueForKey:firstKey];
			if (object)
			{
				textKeyPath = [textKeyPath substringFromIndex:([firstKey length] + 1)];
			}
			else
			{
				object = [self component];
			}
		}
		
		
		// HTML tag
		NSString *tag = [parameters objectForKey:@"tag"];
		if (tag && ![tag isKindOfClass:[NSString class]]) tag = nil;
		
		
		// Flags
		NSArray *flags = [[parameters objectForKey:@"flags"] componentsSeparatedByWhitespace];
		
		// Hyperlink
		KTAbstractPage *hyperlink = nil;
		NSString *hyperlinkKeyPath = [parameters objectForKey:@"hyperlink"];
		if (hyperlinkKeyPath) hyperlink = [[self cache] valueForKeyPath:hyperlinkKeyPath];
		
		
		// Build the text block
		result = [self textblockForKeyPath:textKeyPath
								  ofObject:object
									 flags:flags
								   HTMLTag:tag
						 graphicalTextCode:[parameters objectForKey:@"graphicalTextCode"]
							     hyperlink:hyperlink];
		
		if (!result) result = @"";
	}
	else
	{
		NSLog(@"textblock: usage [[textblock (object:keyPath) property:keyPath (flags:\"some flags\") tag:HTMLTag]]");
	}
	
	return result;
}

- (NSString *)textblockForKeyPath:(NSString *)keypath ofObject:(id)object
							flags:(NSArray *)flags
						  HTMLTag:(NSString *)tag
				graphicalTextCode:(NSString *)GTCode
						hyperlink:(KTAbstractPage *)hyperlink
{
	// Build the text block
	KTWebViewTextBlock *textBlock = [[KTWebViewTextBlock alloc] init];
	
	BOOL fieldEditor = [flags containsObject:@"line"];
	BOOL richText = [flags containsObject:@"block"];
	
	if (!fieldEditor && !richText) [textBlock setEditable:NO];
	[textBlock setFieldEditor:fieldEditor];
	[textBlock setRichText:richText];
	[textBlock setImportsGraphics:[flags containsObject:@"imageable"]];
	if (tag) [textBlock setHTMLTag:tag];
	[textBlock setGraphicalTextCode:GTCode];
	
	if (hyperlink)
	{
		NSString *path = [self pathToPage:hyperlink];
		[textBlock setHyperlink:path];
	}
	
	if ([[self currentPage] isKindOfClass:[KTPage class]])
	{
		[textBlock setPage:(KTPage *)[self currentPage]];
	}
	
	[textBlock setHTMLSourceObject:object];
	[textBlock setHTMLSourceKeyPath:keypath];
	
	
	// Generate HTML
	NSString *result = [textBlock outerHTML:[self HTMLGenerationPurpose]];
	
	
	// Inform delegate
	[self didParseTextBlock:textBlock];
	[textBlock release];
	
	
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
		
		result = [textBlock outerHTML:[self HTMLGenerationPurpose]];
		
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
