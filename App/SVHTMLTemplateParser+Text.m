//
//  SVHTMLTemplateParser+Text.m
//  Marvel
//
//  Created by Mike on 05/03/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "SVHTMLTemplateParser+Private.h"
#import "KTHTMLParserMasterCache.h"

#import "KTMediaContainer.h"
#import "KTMediaFile.h"
#import "KTPage.h"
#import "ContinueReadingLinkTextBlock.h"

#import "NSString+Karelia.h"


@implementation SVHTMLTemplateParser (Text)

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
            
            [[self cache] valueForKeyPath:[parameters objectForKey:@"property"]]; // Keeps the delegate informed
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
		SVHTMLTemplateTextBlock *textBlock = [self textblockForKeyPath:textKeyPath
													     ofObject:object
														    flags:flags
													      HTMLTag:tag
											    graphicalTextCode:[parameters objectForKey:@"graphicalTextCode"]
													    hyperlink:hyperlink];
		
		// Generate HTML
		result = [textBlock outerHTML];
		if (!result) result = @"";
	}
	else
	{
		NSLog(@"textblock: usage [[textblock (object:keyPath) property:keyPath (flags:\"some flags\") tag:HTMLTag]]");
	}
	
	return result;
}

- (SVHTMLTemplateTextBlock *)textblockForKeyPath:(NSString *)keypath ofObject:(id)object
									  flags:(NSArray *)flags
								    HTMLTag:(NSString *)tag
						  graphicalTextCode:(NSString *)GTCode
								  hyperlink:(KTAbstractPage *)hyperlink
{
	// Build the text block
	SVHTMLTemplateTextBlock *result = [[[SVHTMLTemplateTextBlock alloc] initWithParser:self] autorelease];
	
	BOOL fieldEditor = [flags containsObject:@"line"];
	BOOL richText = [flags containsObject:@"block"];
	
	if (!fieldEditor && !richText) [result setEditable:NO];
	[result setFieldEditor:fieldEditor];
	[result setRichText:YES];	// Presumably there must be some cases where this is not desired.
	[result setImportsGraphics:[flags containsObject:@"imageable"]];
	if (tag) [result setHTMLTag:tag];
	[result setGraphicalTextCode:GTCode];
	
	if (hyperlink)
	{
		[result setHyperlinkString:[self pathToObject:hyperlink]];
		[result setTargetString:[self targetStringForPage:hyperlink]];
	}
	
	
	[result setHTMLSourceObject:object];
	[result setHTMLSourceKeyPath:keypath];
	
	
	// Inform delegate
	[self didParseTextBlock:result];
    
    
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
		ContinueReadingLinkTextBlock *textBlock = [[ContinueReadingLinkTextBlock alloc] initWithParser:self];
		[textBlock setFieldEditor:YES];
		[textBlock setRichText:NO];
		[textBlock setImportsGraphics:NO];
		[textBlock setHasSpanIn:NO];
		[textBlock setHTMLSourceObject:[[self cache] valueForKeyPath:[parameters objectAtIndex:0]]];
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
