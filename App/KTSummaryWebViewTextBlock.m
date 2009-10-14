//
//  KTSummaryWebViewTextBlock.m
//  Marvel
//
//  Created by Mike on 04/02/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTSummaryWebViewTextBlock.h"

#import "KTPage.h"

#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "DOMNode+KTExtensions.h"

#import "Debug.h"


@implementation KTSummaryWebViewTextBlock

#pragma mark -
#pragma mark Accessors

/*  We override some stuff to match the standard text block behaviour to our own.
 */

- (BOOL)importsGraphics { return YES; }

- (KTPage *)page { return [self HTMLSourceObject]; }

- (unsigned)truncateCharacters { return myTruncateCharacters; }

- (void)setTruncateCharacters:(unsigned)truncation { myTruncateCharacters = truncation; }

#pragma mark -

/*	When the user starts editing a truncated piece of text, we need to, um, untruncate it
 */
- (BOOL)becomeFirstResponder
{
	KTPage *page = [self HTMLSourceObject];
	if (![page customSummaryHTML] && [page summaryHTMLKeyPath])
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
		
		
		// Insert the new HTML but only if there's something to replace it with
		NSString *editingHTML = [self innerEditingHTML];
		if (![[editingHTML stringByConvertingHTMLToPlainText] isEqualToString:@""])
		{
			[[self DOMNode] setInnerHTML:[self innerEditingHTML]];
			
			
			// Recreate the selection
			DOMNode *startContainer = [[self DOMNode] descendantNodeAtIndexPath:selectionStartIndexPath];
			if (startContainer)
            {
                [selection setStart:startContainer offset:[selection startOffset]];
                
                DOMNode *endContainer = startContainer;
                if (selectionEndIndexPath)
                {
                    endContainer = [[self DOMNode] descendantNodeAtIndexPath:selectionEndIndexPath];
                }
                if (endContainer) [selection setEnd:endContainer offset:selectionEndOffset];
                
                [webView setSelectedDOMRange:selection affinity:NSSelectionAffinityDownstream];
            }
		}
	}
	
	return YES;
}

/*	And after editing, truncate the text again
 */
- (BOOL)resignFirstResponder
{
	BOOL result = [super resignFirstResponder];
	
	if (result)
	{
		KTPage *page = [self HTMLSourceObject];
		if (![page customSummaryHTML] && [page summaryHTMLKeyPath])
		{
			[[self DOMNode] setInnerHTML:[self innerHTML]];
		}
	}
	
	return result;
}

/*	When the user has a custom summary, we override the default behavior to save in the custom summary property,
 *	not the standard key path.
 */
- (void)commitHTML:(NSString *)innerHTML
{
	KTPage *page = [self HTMLSourceObject];
	if ([page customSummaryHTML] || ![page summaryHTMLKeyPath])
	{
		[page setCustomSummaryHTML:innerHTML];
	}
	else
	{
		return [super commitHTML:innerHTML];
	}
}

#pragma mark -
#pragma mark Support

- (NSString *)innerHTML
{
	KTPage *page = [self HTMLSourceObject];
	
	NSString *result;
	if ([page customSummaryHTML] || ![page summaryHTMLKeyPath])
	{
		result = [page customSummaryHTML];
	}
	else
	{
		result = [page summaryHTMLWithTruncation:[self truncateCharacters]];
	}
	
	if (!result) result = @"";
	
    result = [self processHTML:result];
	OBPOSTCONDITION(result);
	return result;
}

- (NSString *)innerEditingHTML
{
	KTPage *page = [self HTMLSourceObject];
	
	NSString *result;
	if ([page customSummaryHTML] || ![page summaryHTMLKeyPath])
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
