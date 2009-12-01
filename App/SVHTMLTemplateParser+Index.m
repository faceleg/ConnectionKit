//
//  SVHTMLTemplateParser+Summaries.m
//  Marvel
//
//  Created by Mike on 08/02/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "SVHTMLTemplateParser+Private.h"

#import "KTAbstractElement+Internal.h"
#import "KTPage.h"
#import "KTSummaryWebViewTextBlock.h"

#import "NSArray+Karelia.h"
#import "NSString+Karelia.h"

#import "Debug.h"


@interface SVHTMLTemplateParser (IndexPrivate)
- (NSString *)summaryForPage:(KTPage *)page truncation:(unsigned)truncation;
- (NSString *)summaryForCollection:(KTPage *)page truncation:(unsigned)truncation;
- (NSString *)summaryForContentOfPage:(KTPage *)page truncation:(unsigned)truncation;
@end


#pragma mark -


@implementation SVHTMLTemplateParser (Index)

#pragma mark -
#pragma mark Index

- (NSString *)indexWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	NSString *result = @"";
	
	NSArray *parameters = [inRestOfTag componentsSeparatedByWhitespace];
	if (parameters && [parameters count] == 2)
	{
		KTAbstractIndex *index = [[self cache] valueForKeyPath:[parameters objectAtIndex:0]];
		NSString *indexTemplate = [index templateHTML];
        
        if (indexTemplate)
        {
            SVHTMLTemplateParser *parser = [self newChildParserWithTemplate:indexTemplate component:index];
            
            NSArray *indexPages = [[self cache] valueForKeyPath:[parameters objectAtIndex:1]];
            [parser overrideKey:@"pages" withValue:indexPages];
            
            result = [parser parseTemplate];
            [parser release];
        }
	}
	else
	{
		NSLog(@"target: usage [[index keyPath.to.index pages.to.index]]");
		
	}
	
	return result;
}

#pragma mark -
#pragma mark Summary

- (NSString *)summaryWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	NSString *result = @"";
	
	NSArray *parameters = [inRestOfTag componentsSeparatedByWhitespace];
	if (parameters && ([parameters count] == 2 || [parameters count] == 3))
	{
		KTPage *page = [[self cache] valueForKeyPath:[parameters objectAtIndex:0]];
        unsigned truncation = [[[self cache] valueForKeyPath:[parameters objectAtIndex:1]] unsignedIntValue];
        result = [self summaryForPage:page truncation:truncation];
		
		// The template can specify that the HTML should be escaped suitably for an RSS feed
		if ([parameters count] == 3)
		{
			result = [result stringByEscapingHTMLEntities];
		}
	}
	else
	{
		NSLog(@"target: usage [[summary page truncation (escapeHTML)]]");
		
	}
	
	
	return result;
}

/*	Generates the summary for the page taking into account its type
 */
- (NSString *)summaryForPage:(KTPage *)page truncation:(unsigned)truncation
{
	if ([page isCollection])
	{
		return [self summaryForCollection:page truncation:truncation];
	}
	else
	{
		return [self summaryForContentOfPage:page truncation:truncation];
	}
}

/*	Collections are a bit trickier to handle than pages. -summaryOfPage will call through to here automatically.
 */
- (NSString *)summaryForCollection:(KTPage *)page truncation:(unsigned)truncation
{
	NSString *result = nil;
	switch ([page collectionSummaryType])
	{
		case KTSummarizeAutomatic:
			result = [self summaryForContentOfPage:page truncation:truncation];
			break;
		
		case KTSummarizeRecentList:
			result = [page titleListHTMLWithSorting:KTCollectionSortLatestAtTop];
			break;
		case KTSummarizeAlphabeticalList:
			result = [page titleListHTMLWithSorting:KTCollectionSortAlpha];
			break;
		
		case KTSummarizeFirstItem:
		{
			result = @"";
			KTPage *firstChild = [[page sortedChildren] firstObjectKS];
			if (firstChild) result = [self summaryForContentOfPage:firstChild truncation:truncation];
			break;
		}
		
		case KTSummarizeMostRecent:
		{
			result = @"";
			NSArray *children = [page childrenWithSorting:KTCollectionSortLatestAtTop inIndex:YES];
			KTPage *recentChild = [children firstObjectKS];
			if (recentChild) result = [self summaryForContentOfPage:recentChild truncation:truncation];
			break;
		}
		
		default:
			OBASSERT_NOT_REACHED("Unknown collection summary type");
	}
	
	return result;
}

/*	Generates a summary of a page WITHOUT considering its type.
 *	Support method used by -summaryOfPage and -summaryOfCollection:
 */
- (NSString *)summaryForContentOfPage:(KTPage *)page truncation:(unsigned)truncation
{
	// Create a text block object to handle truncation etc.
	KTSummaryWebViewTextBlock *textBlock = [[KTSummaryWebViewTextBlock alloc] init];
	[textBlock setHTMLSourceObject:page];
	[textBlock setHTMLSourceKeyPath:[page summaryHTMLKeyPath]];
    [textBlock setTruncateCharacters:truncation];
	
	NSString *result = [textBlock innerHTMLString];
	
	
	// Enclose the HTML in an editable div if it needs it
	if ([page summaryHTMLIsEditable])
	{
		[textBlock setFieldEditor:NO];
		[textBlock setRichText:YES];
		[textBlock setImportsGraphics:YES];
		[textBlock setHasSpanIn:NO];
		
		NSMutableString *buffer = [NSMutableString stringWithString:@"<div"];
        if ([[SVHTMLContext currentContext] generationPurpose] == kGeneratingPreview)
        {
            [buffer appendFormat:@" id=\"%@\" class=\"kBlock kSummary kOptional kImageable\"", [textBlock DOMNodeID]];
        }
        [buffer appendFormat:@">%@</div>", result];
        result = [[buffer copy] autorelease];
		
		
		// Inform the delegate 
		[self didParseTextBlock:textBlock];
	}
	
	
	// Tidy up
	[textBlock release];
	
	return result;
}

@end
