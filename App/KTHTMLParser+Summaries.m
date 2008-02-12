//
//  KTHTMLParser+Summaries.m
//  Marvel
//
//  Created by Mike on 08/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTHTMLParser.h"

#import "KTSummaryWebViewTextBlock.h"


@interface KTHTMLParser (Private)
- (KTHTMLParserMasterCache *)cache;
@end


@interface KTHTMLParser (SummariesPrivate)
- (NSString *)summaryForPage:(KTPage *)page;
- (NSString *)summaryForCollection:(KTPage *)page;
- (NSString *)summaryForContentOfPage:(KTPage *)page;
@end


#pragma mark -


@implementation KTHTMLParser (Summaries)

- (NSString *)summaryWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	NSString *result = @"";
	
	NSArray *parameters = [inRestOfTag componentsSeparatedByWhitespace];
	if (parameters && [parameters count] == 2)
	{
		KTPage *page = [[self cache] valueForKeyPath:[parameters objectAtIndex:0]];
		result = [self summaryForPage:page];
	}
	
	return result;
}

/*	Generates the summary for the page taking into account its type
 */
- (NSString *)summaryForPage:(KTPage *)page
{
	if ([page isCollection])
	{
		return [self summaryForCollection:page];
	}
	else
	{
		return [self summaryForContentOfPage:page];
	}
}

/*	Collections are a bit trickier to handle than pages. -summaryOfPage will call through to here automatically.
 */
- (NSString *)summaryForCollection:(KTPage *)page
{
	NSString *result = nil;
	switch ([page collectionSummaryType])
	{
		case KTSummarizeAutomatic:
			result = [self summaryForContentOfPage:page];
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
			KTPage *firstChild = [[page sortedChildren] firstObjectOrNilIfEmpty];
			if (firstChild) result = [self summaryForContentOfPage:firstChild];
			break;
		}
		
		case KTSummarizeMostRecent:
		{
			result = @"";
			NSArray *children = [page childrenWithSorting:KTCollectionSortLatestAtTop];
			KTPage *recentChild = [children firstObjectOrNilIfEmpty];
			if (recentChild) result = [self summaryForContentOfPage:recentChild];
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
- (NSString *)summaryForContentOfPage:(KTPage *)page
{
	// Create a text block object to handle truncation etc.
	KTSummaryWebViewTextBlock *textBlock = [[KTSummaryWebViewTextBlock alloc] init];
	[textBlock setHTMLSourceObject:page];
	[textBlock setHTMLSourceKeyPath:[page summaryHTMLKeyPath]];
	
	NSString *result = [textBlock summarisedContentHTML];
	
	
	// Enclose the HTML in an editable div if it needs it
	if ([page summaryHTMLIsEditable])
	{
		[textBlock setFieldEditor:NO];
		[textBlock setRichText:YES];
		[textBlock setImportsGraphics:YES];
		[textBlock setHasSpanIn:NO];
		
		result = [NSString stringWithFormat:
			@"<div id=\"%@\" class=\"kBlock kSummary kOptional kImageable\">%@</div>",
			[textBlock DOMNodeID],
			result];
		
		
		// Inform the delegate 
		id delegate = [self delegate];
		if (delegate && [delegate respondsToSelector:@selector(HTMLParser:didParseTextBlock:)])
		{
			[delegate HTMLParser:self didParseTextBlock:textBlock];
		}
	}
	
	
	// Tidy up
	[textBlock release];
	
	return result;
}

@end
