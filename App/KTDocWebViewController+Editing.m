//
//  KTDocWebViewController+Editing.m
//  Marvel
//
//  Created by Mike on 18/12/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "KTDocWebViewController+Private.h"

#import "Debug.h"
#import "KTDocWindowController.h"
#import "KTDocSiteOutlineController.h"
#import "SVHTMLTextBlock.h"
#import "KTWebViewUndoManagerProxy.h"
#import "KTToolbars.h"
#import "WebViewEditingHelperClasses.h"
#import "KTPseudoElement.h"
#import "KTInlineImageElement.h"
#import "KTWebViewComponent.h"
#import "KTPage+Internal.h"
#import "KTDocument.h"

#import "NSArray+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"

#import "DOMNode+Karelia.h"
#import "DOM+KTWebViewController.h"
#import "DOMNode+KTExtensions.h"

#import "KSWebLocation.h"


@interface NSView ( WebHTMLViewHack )
- (NSRect)selectionRect;
- (NSRect)_selectionRect;		// old compatibility version of above
@end


#pragma mark -


@interface KTDocWebViewController (EditingPrivate)
- (void)setCurrentTextEditingBlock:(SVHTMLTextBlock *)textBlock;

- (void)webViewWillEditDOM:(WebView *)webView;
@end


#pragma mark -


@implementation KTDocWebViewController (Editing)



#pragma mark -
#pragma mark Editing Status

- (SVHTMLTextBlock *)currentTextEditingBlock { return myTextEditingBlock; }

- (void)setCurrentTextEditingBlock:(SVHTMLTextBlock *)textBlock
{
	// Ignore unecessary changes
	if (textBlock == myTextEditingBlock) {
		return;
	}
	
	
	if (myTextEditingBlock)
	{
		[myTextEditingBlock resignFirstResponder];
		
		// Kill off the undo actions and other data specific to that editing block
		[myInlineImageElements removeAllObjects];
		[myInlineImageNodes removeAllObjects];
		
		[[[self webViewUndoManagerProxy] undoManager] removeAllActionsWithTarget:self];	// Handles suspend/resume webview refresh stuff
		[[self webViewUndoManagerProxy] removeAllWebViewTargettedActions];
		
		
	}
	
	
	[textBlock retain];
	[myTextEditingBlock release];
	myTextEditingBlock = textBlock;
		
	
	if (textBlock)
	{
		[textBlock becomeFirstResponder];
	}
}

/*	WebView does not have its own -isEditing method so we have to manage one ourself.
 */
- (BOOL)webViewIsEditing { return ([self currentTextEditingBlock] != nil); }

- (BOOL)commitEditing
{
	BOOL result = ![self webViewIsEditing];
	if (!result)	// If there's nothing being edited then -commitEditing upon a nil object returns NO
	{
		result = [[self currentTextEditingBlock] commitEditing];
	}
	
	return result;
}

- (void)webViewDidEndEditing:(NSNotification *)notification
{
	[self setCurrentTextEditingBlock:nil];
}

#pragma mark -
#pragma mark Selection


- (void)webViewDidChangeSelection:(NSNotification *)notification
{
	if ([notification object] != [self webView]) {	// Ignore webviews not our own
		return;
	}
	
	
	
	
	// Change our -currentTextEditingBlock if needed
	WebView *theWebview = [notification object];
	DOMRange *selectedDOMRange = [theWebview selectedDOMRange];
	DOMNode *selectedDOMNode = [selectedDOMRange startContainer];
	
    /// Case 41716: Relying on -firstSelectableParentNode doesn't handle all edge cases. Better to go straight to the text block API which can handle them
    /// I don't quite understand why the flow of this code only calls -setCurrentTextEditingBlock: if a valid block was found, but it's what the old code did and fails assertions otherwise. As far as I can find editing does all the right things still
    if (selectedDOMNode)
    {
        SVHTMLTextBlock *newBlock = [[self mainWebViewComponent] textBlockForDOMNode:selectedDOMNode];
        if (newBlock)
        {
            if (![[self windowController] isEditableElement:[newBlock DOMNode]]) newBlock = nil;
            [self setCurrentTextEditingBlock:newBlock];
        }
    }
    
    
    
	
	NSView *documentView = [[[theWebview mainFrame] frameView] documentView];
	Class WebHTMLView = NSClassFromString(@"WebHTMLView");
	OBASSERTSTRING([documentView isKindOfClass:[WebHTMLView class]], @"documentView not of expected class!");
	
	// do we have an active link panel?
	if ( [[[self windowController] linkPanel] isVisible] )
	{
		[[self windowController] finishLinkPanel:nil]; // process [self contextElementInformation]
	}
	
	// setSelectionRect
	//	 get the webView's selection rectangle
	NSRect unconvertedSelectionRect = NSZeroRect;
	if ([documentView respondsToSelector:@selector(selectionRect)])
	{
		unconvertedSelectionRect = [documentView selectionRect];
	}
	else if ([documentView respondsToSelector:@selector(_selectionRect)])
	{
		unconvertedSelectionRect = [documentView _selectionRect];
	}
	//	 convert to window coordinates
	[[self windowController] setSelectionRect:[documentView convertRect:unconvertedSelectionRect toView:nil]];
	
	// setContextElementInformation
	NSPoint elementPoint;
	if ( [[self windowController] selectionRect].size.width > 0 )
	{
		elementPoint = unconvertedSelectionRect.origin;
	}
	else
	{
		elementPoint = [[self windowController] lastClickedPoint];
	}
	NSMutableDictionary *elementDictionary = [NSMutableDictionary dictionary];
	if ( nil != selectedDOMRange )
	{
		[elementDictionary setObject:selectedDOMRange forKey:KTSelectedDOMRangeKey];
        [elementDictionary addEntriesFromDictionary:[(WebView *)documentView elementAtPoint:elementPoint]];
        [[self windowController] setContextElementInformation:[NSMutableDictionary dictionaryWithDictionary:elementDictionary]];
	} else
        [[self windowController] setContextElementInformation:nil];
	
	
	// update Cut, Copy, Paste menuitems
	//[[self windowController] updateEditMenuItems];
}

#pragma mark -
#pragma mark Change Management

/*!	OK, don't filter stuff.	 For some reason, when I filter the style, it doesn't let valid stuff
 through.  We seem to do OK by filtering later.
 */
- (BOOL)webView:(WebView *)aWebView shouldApplyStyle:(DOMCSSStyleDeclaration *)style toElementsInDOMRange:(DOMRange *)range
{
	OFF((@"%@", NSStringFromSelector(_cmd) ));
	//	NSString *cssText = [style cssText];
	//	cssText = [DOMElement cleanupStyleText:cssText];
	//	[style setCssText:cssText];
	
	[self webViewWillEditDOM:aWebView];
	
	return YES;
}


- (BOOL)webView:(WebView *)aWebView shouldDeleteDOMRange:(DOMRange *)range
{
	[self webViewWillEditDOM:aWebView];
	return YES;
}


/*	Control is passed onto the current text block to handle.
 */
- (BOOL)webView:(WebView *)aWebView shouldInsertNode:(DOMNode *)node replacingDOMRange:(DOMRange *)range givenAction:(WebViewInsertAction)action
	// node is DOMDocumentFragment
{
	BOOL result = NO;
	
	SVHTMLTextBlock *textBlock = [[self mainWebViewComponent] textBlockForDOMNode:[range startContainer]];
	if (textBlock)
    {
		result = [textBlock webView:aWebView shouldInsertNode:node replacingDOMRange:range givenAction:action];
	}
	
	
	if (result)
	{
		[self webViewWillEditDOM:aWebView];
	}
	
	return result;
}


/*	Called whenever the user tries to type something.
 *	We never allow a tab to be entered. (Although such a case never seems to occur)
 */
- (BOOL)webView:(WebView *)aWebView shouldInsertText:(NSString *)text replacingDOMRange:(DOMRange *)range givenAction:(WebViewInsertAction)action
{
	BOOL result = YES;
	
	if ([text isEqualToString:@"\t"])	// Disallow tabs
	{
		result = NO;
	}
	
	
	if (result)
	{
		[self webViewWillEditDOM:aWebView];
	}
	
	return result;
}


/*	When certain actions are taken we override them
 */
- (BOOL)webView:(WebView *)aWebView doCommandBySelector:(SEL)selector
{
	if (aWebView != [self webView]) {	// Ignore webviews not our own
		return NO;
	}
	
	
	// When the user hits return, end editing if in a field editor.
	if (selector == @selector(insertNewline:) && [[self currentTextEditingBlock] isFieldEditor])
	{
		[self commitEditing];
		return YES;
	}
	// When the user hits option-return insert a line break.
	else if (selector == @selector(insertNewlineIgnoringFieldEditor:))
	{
		[[[aWebView window] firstResponder] insertLineBreak:self];
		return YES;
	}
	
	return NO;
}

#pragma mark -
#pragma mark Undo Management

/*	We want to commit HTML to the MOC in a fashion that makes sense to the user if they choose to undo it later.
 *	At present, the best strategy is this:
 *
 *		1. WebEditingDelegate methods inform us that the DOM is about to change. Record the current HTML
 *		2. If WebKit registers an undo operation, commit that HTML to the MOC
 *		3. Dispose of the HTML once WebKit is done with that edit
 */

- (void)webViewWillEditDOM:(WebView *)webView
{
	myMidEditHTML = [[[self currentTextEditingBlock] liveInnerHTML] copy];
}

- (void)webViewDidEditChunk:(NSNotification *)notification
{
	if (myMidEditHTML)
	{
		[[self currentTextEditingBlock] commitHTML:myMidEditHTML];
	}
}

- (void)webViewDidChange:(NSNotification *)notification
{
	[myMidEditHTML release];
	myMidEditHTML = nil;
}

#pragma mark -
#pragma mark Undo Manager Proxy

- (KTWebViewUndoManagerProxy *)webViewUndoManagerProxy
{
	if (!myUndoManagerProxy)
	{
		myUndoManagerProxy = [[KTWebViewUndoManagerProxy alloc] initWithUndoManager:[[[self windowController] document] undoManager]];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(webViewDidEditChunk:)
													 name:KTWebViewDidEditChunkNotification
												   object:myUndoManagerProxy];
	}
	
	return myUndoManagerProxy;
}

- (NSUndoManager *)undoManagerForWebView:(WebView *)webView
{
	return (NSUndoManager *)[self webViewUndoManagerProxy];
}

#pragma mark -
#pragma mark Unused delegate methods

- (BOOL)webView:(WebView *)webView shouldChangeTypingStyle:(DOMCSSStyleDeclaration *)currentStyle toStyle:(DOMCSSStyleDeclaration *)proposedStyle
{
	OFF((@"%@", NSStringFromSelector(_cmd) ));
	return [[self currentTextEditingBlock] isRichText];
	// only allow styling if this our property is marked as rich text, with HTML suffix....
}

- (void)webViewDidChangeTypingStyle:(NSNotification *)notification
{
	;
}

#pragma mark -
#pragma mark Links

- (BOOL)validateCreateLinkItem:(id <NSValidatedUserInterfaceItem>)item title:(NSString **)title
{
	if (title)
	{
		*title = TOOLBAR_CREATE_LINK;
	}
	
	if (![self currentTextEditingBlock]) return NO;		// Can't create a link if nothing is being edited
    
	
	// A discontinuous selection must be to create a link
	DOMRange *selection = [[self webView] selectedDOMRange];
	if ([selection startContainer] == [selection endContainer])
	{
		// Check for an existing link containing the selection, that will mean we can edit it.
		if (title && [[selection startContainer] isContainedByElementOfClass:[DOMHTMLAnchorElement class]])
		{
			*title = TOOLBAR_EDIT_LINK;
		}
	}
	
	return YES;
}

#pragma mark -
#pragma mark Embedded Images

- (NSString *)uniqueIDForInlineImageNode:(DOMHTMLImageElement *)node
{
	NSArray *matches = [myInlineImageNodes allKeysForObject:node];
	NSString *result = [matches firstObjectKS];
	
	if (!result)
	{
		result = [NSString shortUUIDString];
		[myInlineImageNodes setObject:node forKey:result];
	}
	
	return result;
}

- (KTInlineImageElement *)inlineImageEementForUniqueNodeID:(NSString *)nodeID
{
	KTInlineImageElement *result = [myInlineImageElements objectForKey:nodeID];
	return result;
}

- (KTInlineImageElement *)inlineImageElementForNode:(DOMHTMLImageElement *)node
										  container:(KTAbstractElement *)container
{
	NSString *nodeID = [self uniqueIDForInlineImageNode:node];
	KTInlineImageElement *result = [self inlineImageEementForUniqueNodeID:nodeID];
	
	if (!result)
	{
		result = [KTInlineImageElement inlineImageElementWithID:nodeID DOMNode:node container:container];
		[myInlineImageElements setObject:result forKey:nodeID];
	}
	
	return result;
}

#pragma mark -
#pragma mark Editing Actions

- (IBAction)deselectAll:(id)sender
{
	NSView *documentView = [[[[self webView] mainFrame] frameView] documentView];
	if ([documentView conformsToProtocol:@protocol(WebDocumentText)])
	{
		[(NSView <WebDocumentText> *)documentView deselectAll];
	}
}

- (BOOL)isSelectionTypewriter:(DOMRange *)range
{
	if (nil == range) return NO;
	DOMNode *node = [range startContainer];

	while (![node isKindOfClass:[DOMElement class]])
	{
		node = [node parentNode];
	}

	NSString *styleString = [((DOMElement*)node) getAttribute:@"style"];
	return ([[[node nodeName] lowercaseString] isEqualToString:@"tt"] || NSNotFound != [styleString rangeOfString:@"monospace"].location);
}

- (BOOL)isSelectionStrikeout:(DOMRange *)range
{
	if (nil == range) return NO;
	DOMNode *node = [range startContainer];

	while (![node isKindOfClass:[DOMElement class]])
	{
		node = [node parentNode];
	}
	/*
	 // TODO: when webkit implements style sheet stuff, this could be done better this way.
	 DOMCSSStyleDeclaration *style = [[node ownerDocument] getComputedStyle:(DOMElement *)node :@""];
	 
	 NSLog(@"cssText = %@", [style cssText]);
	 NSLog(@"font value = %@", [style getPropertyValue:@"font"]);
	 NSLog(@"font css value = %@", [style getPropertyCSSValue:@"font"]);
	 NSLog(@"font priority = %@", [style getPropertyPriority:@"font"]);
	 
	 NSMutableString *string = [NSMutableString string];
	 int i;
	 for (i = 0 ; i < [style length] ; i++ )
	 {
		 [string appendString:[style item:i]];
		 [string appendString:@" "];
	 }
	 NSLog(@"items (%d) = %@", [style length], string);
	 
	 
	 //NSString *val = [style getPropertyValue:@"font"];
	 //NSLog(@"style = %@ ...  %@", val, [style cssText]);
	 // If fixed pitch, mark that -- otherwise, do not output this style
	 // if ([theFont isFixedPitch])
	 */

	NSString *styleString = [((DOMElement*)node) getAttribute:@"style"];
	return (NSNotFound != [styleString rangeOfString:@"line-through"].location);

}

- (IBAction)strikeout:(id)sender
{
	DOMRange *range = [[self webView] selectedDOMRange];
	if (nil != range)
	{		
		if (![self isSelectionStrikeout:range]) // turn on?
		{
			static StrikeThroughOn *sStrikeThroughOn = nil;
			if (nil == sStrikeThroughOn) sStrikeThroughOn = [[StrikeThroughOn alloc] init];
			[[self webView] changeAttributes:sStrikeThroughOn];
		}
		else
		{
			static StrikeThroughOff *sStrikeThroughOff = nil;
			if (nil == sStrikeThroughOff) sStrikeThroughOff = [[StrikeThroughOff alloc] init];
			[[self webView] changeAttributes:sStrikeThroughOff];
		}
	}
}

// TODO: -- change this to just insert TT as the cleanup does?	 How to make undoable?

// TODO: -- hook this back up to the UI, in the next version.  Took out for now, punting.


- (IBAction)typewriter:(id)sender
{
	DOMRange *range = [[self webView] selectedDOMRange];
	if (nil != range)
	{
		if (![self isSelectionTypewriter:range])	// turn on?
		{
			static TypewriterOn *sTypewriterOn = nil;
			if (nil == sTypewriterOn) sTypewriterOn = [[TypewriterOn alloc] init];
			[[self webView] changeAttributes:sTypewriterOn];
		}
		else
		{
			static TypewriterOff *sTypewriterOff = nil;
			if (nil == sTypewriterOff) sTypewriterOff = [[TypewriterOff alloc] init];
			[[self webView] changeAttributes:sTypewriterOff];
		}
	}
}

// paste some raw HTML
- (IBAction)pasteLink:(id)sender
{
	NSArray *locations = [KSWebLocation webLocationsFromPasteboard:[NSPasteboard generalPasteboard]];
	
	if ([locations count])
	{
		// Figure out the URL and title to paste
		NSURL *URL = [[locations objectAtIndex:0] URL];
		NSString *title = [[locations objectAtIndex:0] title];
		
		NSString *urlString = [URL absoluteString];
		
		NSString *undoActionName = [[self windowController] createLink:urlString desiredText:title openLinkInNewWindow:NO];
		
		// update webview to reflect node changes
		[[self webEditor] didChange];
		[[self windowController] setContextElementInformation:nil];
		
		[[[self webView] undoManager] setActionName:undoActionName];
		
		
		// OLD METHOD -- PASTE BLINDLY OVER EXISTING TEXT
		//NSString *linkHTML = [NSString stringWithFormat:@"<a href=\"%@\">%@</a>", [URL absoluteString], title];
		//[[self webView] replaceSelectionWithMarkupString:linkHTML];
	}
}


/*  Processes the current selection in an undo-compatible fashion such that all styling information is removed.
 */
- (IBAction)clearStyles:(id)sender
{
	static NSSet *blacklist;
    if (!blacklist)
    {
        blacklist = [[NSSet alloc] initWithObjects:
                     @"B",
                     @"BASEFONT",
                     @"BDO",
                     @"BIG"
                     @"CENTER",
                     @"CITE",
                     @"CODE"
                     @"DEL",
                     @"EM",
                     @"FONT",
                     @"I",
                     @"INS",
                     @"KBD",
                     @"PRE",
                     @"Q",
                     @"S",
                     @"SAMP",
                     @"SMALL",
                     @"SPAN",
                     @"STRIKE",
                     @"STRONG",
                     @"SUB",
                     @"SUP",
                     @"TT",
                     @"U",
                     @"VAR",
                     @"XMP", nil];
    }
    
    
    // Ensure there's a selection to work with
    DOMRange *selection = [[self webView] selectedDOMRange];
	if (selection && ![selection collapsed])
    {
        // Clone the selection so we can work on it without upsetting the undo manager
        DOMDocumentFragment *result = [selection cloneContents];
            
        
        // Clean each childNode of the fragment
        DOMNodeList *childNodes = [result childNodes];
        unsigned long i;
        for (i = 0; i < [childNodes length]; i++)
        {
            DOMNode *aNode = [childNodes item:i];
            if ([aNode isKindOfClass:[DOMHTMLElement class]])
            {
                [(DOMHTMLElement *)aNode unstyleWithBlacklist:blacklist];
            }
        }
        
        
        // Normalize post-surgery. (Ensures no text nodes needlessly split)
        [result normalize];
        
        
        // Feed the unstyled nodes back into the webview
        [self webViewWillEditDOM:[self webView]];           // -[WebView replaceSelectioWithNode:] calls -didChange for
        [[self webView] replaceSelectionWithNode:result];   // us, but we need to trigger -willChange
    }
}

#pragma mark -
#pragma mark Menu Validation

// paste some raw HTML

- (IBAction)pasteTextAsMarkup:(id)sender
{
    NSString *markup = [[NSPasteboard generalPasteboard] stringForType:NSStringPboardType];
    [[self webView] replaceSelectionWithMarkupString:markup ? markup : @""];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	BOOL result = YES;

	SEL action = [menuItem action];
    
    // Clear Styles - Enable when the user selects some editable text
    if (action == @selector(clearStyles:))
	{
		result = NO;
        if ([self currentTextEditingBlock])
        {
            DOMRange *selection = [[self webView] selectedDOMRange];
            result = (selection && [selection startContainer] && [selection endContainer] && ![selection collapsed]);
        }
	}
	else if (action == @selector(typewriter:))
	{
		DOMRange *range = [[self webView] selectedDOMRange];
		if (nil != range)
		{
			[menuItem setState:[self isSelectionTypewriter:range] ? NSOnState : NSOffState];
		}
		return (nil != range);
	}
	else if (action == @selector(strikeout:))
	{
		DOMRange *range = [[self webView] selectedDOMRange];
		if (nil != range)
		{
			[menuItem setState:[self isSelectionStrikeout:range] ? NSOnState : NSOffState];
		}
		return (nil != range);
	}
	
    // Paste HTML into Text
    else if (action == @selector(pasteTextAsMarkup:))
	{
		result = [self webViewIsEditing];
	}
	
    // "Paste Link"
	else if (action == @selector(pasteLink:))
	{
		NSArray *locations = [KSWebLocation webLocationsFromPasteboard:[NSPasteboard generalPasteboard]];
		BOOL result = (locations != nil && [locations count] > 0);
		return result;
	}
    
	// View type
    else if (action == @selector(selectWebViewViewType:))
	{
		// Select the correct item for the current view type
		KTWebViewViewType menuItemViewType = [menuItem tag];
		if (menuItemViewType == [self viewType]) {
			[menuItem setState:NSOnState];
		}
		else {
			[menuItem setState:NSOffState];
		}
		
		// Disable the RSS item if the current page does not support it
		BOOL result = YES;
		if (menuItemViewType == KTRSSSourceView || menuItemViewType == KTRSSView)
		{
			KTPage *page = [self page];
			if (![page collectionCanSyndicate] || ![page collectionSyndicate]) {
				result = NO;
			}
		}
		
		return result;
	}
	
	// "Make Text Bigger" makeTextLarger:
	else if (action == @selector(makeTextLarger:))
	{
		result = [[self webView] canMakeTextLarger];
	}
	
	// "Make Text Smaller" makeTextSmaller:
	else if (action == @selector(makeTextSmaller:))
	{
		result = [[self webView] canMakeTextSmaller];
	}
	
	else if (action == @selector(makeTextStandardSize:))
	{
		result = [[self webView] canMakeTextStandardSize];
	}
	
	
    return result;
}

@end
