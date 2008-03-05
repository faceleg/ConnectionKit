//
//  KTSummaryWebViewTextBlock.m
//  Marvel
//
//  Created by Mike on 04/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTSummaryWebViewTextBlock.h"

#import "KTWebKitCompatibility.h"
#import "KTPage.h"
#import "DOMNode+KTExtensions.h"

@implementation KTSummaryWebViewTextBlock

/*	When the user starts editing a truncated piece of text, we need to, um, untruncate it
 */
- (BOOL)becomeFirstResponder
{
	KTPage *page = [self HTMLSourceObject];
	if (![page customSummaryHTML])
	{
		// We need to maintain the selected DOMRange after the full text has been inserted.
		// Figure out index paths to the selection
		WebView *webView = [[[[self DOMNode] ownerDocument] webFrame] webView];
		DOMRange *selection = [webView selectedDOMRange];
		
		DOMNode *selectionStart = [selection startContainer];
		NSIndexPath *selectionStartIndexPath = [selectionStart indexPathFromNode:[self DOMNode]];
		
		DOMNode *selectionEnd = [selection endContainer];
		int selectionEndOffset = [selection endOffset];
		NSIndexPath *selectionEndIndexPath = nil;
		if (selectionStart != selectionEnd)
		{
			selectionEndIndexPath = [selectionEnd indexPathFromNode:[self DOMNode]];
		}
		
		
		// Insert the new HTML
		[[self DOMNode] setInnerHTML:[self innerEditingHTML]];
		
		
		// Recreate the selection
		DOMNode *startContainer = [[self DOMNode] childNodeAtIndexPath:selectionStartIndexPath];
		[selection setStart:startContainer offset:[selection startOffset]];
		
		DOMNode *endContainer = startContainer;
		if (selectionEndIndexPath) startContainer = [[self DOMNode] childNodeAtIndexPath:selectionEndIndexPath];
		[selection setEnd:endContainer offset:selectionEndOffset];
		
		[webView setSelectedDOMRange:selection affinity:NSSelectionAffinityDownstream];
	}
	
	return [super becomeFirstResponder];
}

/*	And after editing, truncate the text again
 */
- (BOOL)resignFirstResponder
{
	BOOL result = [super resignFirstResponder];
	
	if (result)
	{
		KTPage *page = [self HTMLSourceObject];
		if (![page customSummaryHTML])
		{
			[[self DOMNode] setInnerHTML:[self innerHTML]];
		}
	}
	
	return result;
}

/*	When the user has a custom summary, we override the default behavior to save in the custom summary property,
 *	not the standard key path.
 */
- (BOOL)commitEditing
{
	KTPage *page = [self HTMLSourceObject];
	if ([page customSummaryHTML])
	{
		[page setCustomSummaryHTML:[[self DOMNode] cleanedInnerHTML]];
		return YES;
	}
	else
	{
		return [super commitEditing];
	}
}

#pragma mark -
#pragma mark Support

- (NSString *)innerHTML
{
	KTPage *page = [self HTMLSourceObject];
	
	NSString *result;
	if ([page customSummaryHTML])
	{
		result = [page customSummaryHTML];
	}
	else
	{
		result = [page summaryHTMLWithTruncation:[[page parent] integerForKey:@"collectionTruncateCharacters"]];
	}
	
	return result;
}

- (NSString *)innerEditingHTML
{
	KTPage *page = [self HTMLSourceObject];
	
	NSString *result;
	if ([page customSummaryHTML])
	{
		result = [page customSummaryHTML];
	}
	else
	{
		result = [[self HTMLSourceObject] valueForKeyPath:[self HTMLSourceKeyPath]];
	}
	
	return result;
}

#pragma mark -
#pragma mark Custom Summaries

/*	Swap our summarised HTML into the customHTML
 */
- (IBAction)overrideSummary:(id)sender		// respond to menu
{
	KTPage *page = [self HTMLSourceObject];
	[page setCustomSummaryHTML:[self innerHTML]];
	[[self DOMNode] setInnerHTML:[self innerEditingHTML]];
}

/*	Remove the page's custom summary
 */
- (IBAction)unOverrideSummary:(id)sender		// respond to menu
{
	KTPage *page = [self HTMLSourceObject];
	[page setCustomSummaryHTML:nil];
	[[self DOMNode] setInnerHTML:[self innerEditingHTML]];
}


@end
