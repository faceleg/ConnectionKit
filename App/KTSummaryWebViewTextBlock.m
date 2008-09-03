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

#pragma mark -

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
                [selection setEnd:endContainer offset:selectionEndOffset];
                
                [webView setSelectedDOMRange:selection affinity:NSSelectionAffinityDownstream];
            }
		}
	}
	
	myIsEditing = YES;
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
		if (![page customSummaryHTML])
		{
			[[self DOMNode] setInnerHTML:[self innerHTML:kGeneratingPreview]];
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

- (NSString *)innerHTML:(KTHTMLParser *)parser
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
	
	if (!result) result = @"";
	
    result = [self processHTML:result withParser:parser];
	OBPOSTCONDITION(result);
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
	[page setCustomSummaryHTML:[self innerHTML:kGeneratingPreview]];
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
