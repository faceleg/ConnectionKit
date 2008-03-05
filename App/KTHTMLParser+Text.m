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
#import "KTWebViewTextBlock.h"

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
		
		
		// Convert flags to CSS classnames. i.e. prepend "k" on each one.
		NSArray *flags = [[parameters objectForKey:@"flags"] componentsSeparatedByWhitespace];
		NSMutableArray *flagClasses = [NSMutableArray arrayWithCapacity:[flags count]];
		
		NSEnumerator *flagsEnumerator = [flags objectEnumerator];
		NSString *aFlag;
		while (aFlag = [flagsEnumerator nextObject])
		{
			[flagClasses addObject:[NSString stringWithFormat:@"k%@", [aFlag capitalizedString]]];
		}
		
		
		// Build the text block
		result = [self textblockForKeyPath:textKeyPath ofObject:object flags:flagClasses];
		if (!result) result = @"";
	}
	else
	{
		NSLog(@"textblock: usage [[textblock property:text.keyPath (flags:\"some flags\")]]");
	}
	
	return result;
}

- (NSString *)textblockForKeyPath:(NSString *)keypath ofObject:(id)object flags:(NSArray *)flags
{
	// What database entity does this text correspond to?
	NSString *pseudoEntity;
	if ([object isKindOfClass:[NSManagedObject class]])
	{
		pseudoEntity = [[(NSManagedObject *)object entity] name];
	}
	else
	{
		pseudoEntity = NSStringFromClass([object class]);
	}
	if ([pseudoEntity isEqualToString:@"Root"]) pseudoEntity = @"Page";
	
	
	// Fetch the text content
	NSString *text = [object valueForKeyPath:keypath];
	if (!text) text = @"";
	
	
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
	
	
	// Construct the <div>
	NSString *result = [NSString stringWithFormat:@"<div id=\"k-%@-%@-%@\" class=\"%@\">\r%@\r</div>",
										pseudoEntity,
										keypath,
										[(KTAbstractElement *)[self component] uniqueID],
										[flags componentsJoinedByString:@" "],
										text];
	
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
		KTWebViewTextBlock *textBlock = [[KTWebViewTextBlock alloc] init];
		[textBlock setFieldEditor:YES];
		[textBlock setRichText:NO];
		[textBlock setImportsGraphics:NO];
		[textBlock setHasSpanIn:NO];
		[textBlock setHTMLSourceObject:[self component]];
		[textBlock setHTMLSourceKeyPath:@"page.master.continueReadingLinkFormat"];
		
		result = [NSString stringWithFormat:@"<span id=\"%@\" class=\"kLine\">\r%@\r</span>",
											[textBlock DOMNodeID],
											[[textBlock HTMLSourceObject] valueForKeyPath:[textBlock HTMLSourceKeyPath]]];
		
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
