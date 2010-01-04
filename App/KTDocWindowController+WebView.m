//
//	KTDocWindowController+WebView.m
//	Marvel
//
//	Created by Dan Wood on 5/4/05.
//	Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "KTDocWindowController.h"

#import "KT.h"
#import "KTAbstractElement+Internal.h"
#import "KTAppDelegate.h"
#import "KSBorderlessWindow.h"
#import "KTDesign.h"
#import "KTDocSiteOutlineController.h"
#import "KTDocWebViewController.h"
#import "KTWebViewComponent.h"
#import "KTDocument.h"
#import "KTDocumentInfo.h"
#import "KTElementPlugin.h"
#import "KTInfoWindowController.h"
#import "KTLinkSourceView.h"
#import "KTMaster.h"
#import "KTPage.h"
#import "KTPseudoElement.h"
#import "KSSilencingConfirmSheet.h"
#import "KTSummaryWebViewTextBlock.h"
#import "KSTextField.h"

#import "NSArray+Karelia.h"
#import "NSAppleScript+Karelia.h"
#import "NSApplication+Karelia.h"
#import "NSBundle+KTExtensions.h"
#import "NSImage+Karelia.h"
#import "NSImage+KTExtensions.h"
#import "NSString+Karelia.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSURL+Karelia.h"

#import "DOMNode+KTExtensions.h"
#import "DOM+KTWebViewController.h"
#import "WebView+Karelia.h"


#import "RoundedBox.h"

#import <CoreServices/CoreServices.h>
#import <QuartzCore/QuartzCore.h>

#import "Registration.h"

#import "Debug.h"


#define CREATE_LINK_MENUITEM_TITLE			NSLocalizedString(@"Create Link...", "Create Link... MenuItem")
#define EDIT_LINK_MENUITEM_TITLE			NSLocalizedString(@"Edit Link...", "Edit Link... MenuItem")


typedef enum {
    WebKitEditableLinkDefaultBehavior = 0,
    WebKitEditableLinkAlwaysLive,
    WebKitEditableLinkOnlyLiveWithShiftKey,
    WebKitEditableLinkLiveWhenNotFocused
} WebKitEditableLinkBehavior;


@interface WebPreferences (WebPrivate)

- (WebKitEditableLinkBehavior)editableLinkBehavior;
- (void)setEditableLinkBehavior:(WebKitEditableLinkBehavior)behavior;
@end


@interface DOMHTMLElement ( newWebKit )
- (void) focus;
@end


NSString *KTSelectedDOMRangeKey = @"KTSelectedDOMRange";


@interface NSObject (WebBridgeHack )
- (DOMRange *)dragCaretDOMRange;
@end


@interface NSView ( WebBridgeHack )
- (id) _bridge;	// WebFrameBridge
@end


@interface KTDocWebViewController (EditingPrivate)
- (void)setCurrentTextEditingBlock:(KTHTMLTextBlock *)textBlock;
@end


@interface KTDocWindowController ( WebViewPrivate )

- (NSString *)savedPageletStyle;
- (NSPoint)linkPanelTopLeftPointForSelectionRect:(NSRect)aSelectionRect;
- (DOMHTMLElement *)elementOfClass:(NSString *)aDesiredClass enclosing:(DOMNode *)aNode;



- (void)selectInlineIMGNode:(DOMNode *)aNode container:(KTAbstractElement *)aContainer;

- (NSString *)createLink:(NSString *)link desiredText:(NSString *)aString openLinkInNewWindow:(BOOL)openLinkInNewWindow;
- (NSString *)removeLinkWithDOMRange:(DOMRange *)selectedRange;

- (void)insertHref:(NSString *)aURLAsString inRange:(DOMRange *)aRange;
- (void)insertText:(NSString *)aTextString href:(NSString *)aURLAsString inRange:(DOMRange *)aRange atPosition:(long)aPosition;

@end


#pragma mark -


@implementation KTDocWindowController (WebView)

/*!	More initialization code specific to the webview, called from windowDidLoad
*/

- (void)webViewDidLoad
{
	WebView *webView = [[self webViewController] webView];
    [webView setApplicationNameForUserAgent:[NSApplication applicationName]];
	
	[webView setPreferencesIdentifier:[NSApplication applicationName]];
	if ([[webView preferences] respondsToSelector:@selector(setEditableLinkBehavior:)])
	{
		[[webView preferences] setEditableLinkBehavior:WebKitEditableLinkLiveWhenNotFocused];
	}
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[webView setContinuousSpellCheckingEnabled:[defaults boolForKey:@"ContinuousSpellChecking"]];
	// Set UI delegate -- we don't actually use the built-in methods, but we use our custom
	// method for detecting clicks.
	[webView setUIDelegate:self];				// WebUIDelegate
	
	/*
	 // doesn't actually work yet
	 DOMDocument *document = [[oWebView mainFrame] DOMDocument];
	 [document addEventListener:@"mousedown"
							   :self
							   :YES];
	 */
	[self setStatusField:@""];
}

#pragma mark -
#pragma mark Image Replacement

- (NSString *)codeForDOMNodeID:(NSString *)anID		// id like k-Entity-Property-434-h1h
{
	NSArray *dashComponents = [anID componentsSeparatedByString:@"-"];
	if ([dashComponents count] < 5)
	{
		return nil;		// code is optional, so return nil if it's not there
	}
	NSString *property = [dashComponents objectAtIndex:4];
	return property;
}

- (NSString *)propertyNameForDOMNodeID:(NSString *)anID	// id like k-Entity-Property-434-h1h
{
	NSString *result = nil;
	NSArray *dashComponents = [anID componentsSeparatedByString:@"-"];
	if ([dashComponents count] > 2)
	{
		result = [dashComponents objectAtIndex:2];
	}
	return result;
}


- (id)itemForDOMNodeID:(NSString *)anID	// id like k-Entity-Property-434-h1h
{
	id result = nil;
	
	NSArray *dashComponents = [anID componentsSeparatedByString:@"-"];
	if ([dashComponents count] < 4)
	{
		return nil;
	}
	
	NSString *entityName= [dashComponents objectAtIndex:1];
	NSString *uniqueID	= [dashComponents objectAtIndex:3];
	
	if ([entityName isEqualToString:@"Document"])
	{
		return [self document];		// don't need to look up object; it's this document!
	}
	else if ([entityName isEqualToString:@"Root"])
	{
		return [[[self document] documentInfo] root];	// don't need to look up object; it's the root
	}
	
	// peform fetch
	NSManagedObjectContext *context = [[self document] managedObjectContext];
	result = [context objectWithUniqueID:uniqueID];
	
	return result;
}


/*!	Verifies that this is an editable entity.  Assumes it's an editable class; it makes sure if it's a page it's an editable summary
*/
- (BOOL)isEditableElement:(DOMHTMLElement *)aDOMHTMLElement
{
	NSString *theClass = [aDOMHTMLElement className];
	
	BOOL result = [DOMNode isEditableFromDOMNodeClass:theClass];
	if (result && [DOMNode isSummaryFromDOMNodeClass:theClass])
	{
		// further scrutiny if it's a summary element
		NSString *theID = [aDOMHTMLElement idName];
		if (nil != theID)
		{
			id selectedItem = [self itemForDOMNodeID:theID];
			if ([selectedItem isKindOfClass:[KTPage class]])
			{
				KTPage *page = (KTPage *)selectedItem;
				if ([page isCollection])
				{
					// yes only if the page is a KTSummarizeAutomatic summary type
					result = ([page collectionSummaryType] == KTSummarizeAutomatic);
				}
			}
		}
	}
	return result;
}

#pragma mark -
#pragma mark Accessors (Special)

- (NSMutableDictionary *)contextElementInformation
{
	return myContextElementInformation;
}

- (void)setContextElementInformation:(NSMutableDictionary *)aContextElementInformation
{
	[aContextElementInformation retain];
	[myContextElementInformation release];
	myContextElementInformation = aContextElementInformation;
}

- (BOOL)selectedDOMRangeIsEditable
{
	DOMRange *selectedRange = [[[self webViewController] webView] selectedDOMRange];
	if ( nil == selectedRange )
	{
		return NO;
	}
	DOMHTMLElement *selectableNode = [[selectedRange startContainer] firstSelectableParentNode];
	
	return ( (nil != selectableNode) && [self isEditableElement:selectableNode] );
}

- (BOOL)selectedDOMRangeIsLinkableButNotRawHtmlAllowingEmpty:(BOOL)canBeEmpty
{
	DOMRange *selectedRange = [[[self webViewController] webView] selectedDOMRange];
	if ( nil == selectedRange )
	{
		return NO; // no selected text, not even an insertion point
	}
	
	if ( !canBeEmpty && ([selectedRange startOffset] == [selectedRange endOffset]) )
	{
		return NO; // no actual text selected, probably just an insertion point
	}
	
	DOMHTMLElement *selectableNode = [[selectedRange startContainer] firstSelectableParentNode];
    
    BOOL nodeContainsKHtml = NO;
    if ( (nil != selectableNode) && [[selectableNode idName] hasPrefix:@"k-"] )
    {
        NSString *classes = [selectableNode className];
        if ( NSNotFound != [classes rangeOfString:@"kHtml"].location )
        {
            nodeContainsKHtml = YES;
        }
    }        
	
    BOOL result = ( !nodeContainsKHtml
					&& (nil != selectableNode) 
					&& [self isEditableElement:selectableNode] 
					&& [DOMNode isLinkableFromDOMNodeClass:[selectableNode className]] 
					);
	return result;
}

#pragma mark -
#pragma mark WebUIDelegate Methods

- (KTAbstractElement *) selectableItemAtPoint:(NSPoint)aPoint itemID:(NSString **)outIDString
{
	KTAbstractElement *result = nil;
	NSDictionary *item = [[[self webViewController] webView] elementAtPoint:aPoint];
	DOMNode *aNode = [item objectForKey:WebElementDOMNodeKey];
	NSString *theID = nil;
	DOMHTMLElement *selectedNode = [aNode firstSelectableParentNode];
	
	if (nil != selectedNode)
	{
		theID = [selectedNode idName];
		if (nil != theID)
		{
			result = [self itemForDOMNodeID:theID];
		}
	}
	if (nil != outIDString)
	{
		*outIDString = theID;
	}
	return result;
}

/*!	Called if you click on a pagelet owned by another page.	 Selects that pagelet and its enclosing page!
Node was retained so that it lives to this invocation!
*/
- (void)selectOwnerPageAndPageletRetainedElement:(DOMHTMLElement *)anElement
{
	KTPagelet *pagelet = [self pageletEnclosing:anElement];
	[[self siteOutlineController] setSelectedObjects:[NSSet setWithObject:[pagelet page]]];
		
// FIXME: - here I need to find the DOM element with the same ID as the given pagelet.
		
	[[self webViewController] performSelector:@selector(selectPagelet:) withObject:pagelet afterDelay:0.4];	// long delay to accomdate refresh we seem to get 
	
	[anElement autorelease];		// go ahead and let it go now
}

// http://lists.apple.com/archives/webkitsdk-dev/2006/Apr/msg00018.html

// Just log javacript errors in the standard console; it may be helpful for us or for people who put javascript into their stuff.

- (void)webView:(WebView *)sender addMessageToConsole:(NSDictionary *)aDict
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:@"LogJavaScript"])
	{
		NSString *message = [aDict objectForKey:@"message"];
		NSString *lineNumber = [aDict objectForKey:@"lineNumber"];
		if (!lineNumber) lineNumber = @""; else lineNumber = [NSString stringWithFormat:@" line %@", lineNumber];
		// NSString *sourceURL = [aDict objectForKey:@"sourceURL"]; // not that useful, it's an applewebdata
		NSLog(@"JavaScript%@> %@", lineNumber, message);
	}
}

/*!	This is my own delegate method for dealing with a click.  Store the selected ID away, and flash the rectangle of what was clicked, using an overlay window so we don't interfere with the WebView.

Note that this method is called AFTER the webview handles the click.
*/
- (void)webView:(WebView *)sender singleClickAtCoordinates:(NSPoint)aPoint modifierFlags:(unsigned int)modifierFlags
{
	NSString *leftDoubleQuote = NSLocalizedString(@"\\U201C", "left double quote");
	NSString *rightDoubleQuote = NSLocalizedString(@"\\U201D", "right double quote");

	// if the webview takes a click, automatically close the link panel
	if ( [oLinkPanel isVisible] )
	{
		[self finishLinkPanel:nil];
	}
	
	[self setLastClickedPoint:aPoint];
	
	NSDictionary *item = [[[self webViewController] webView] elementAtPoint:aPoint];
	DOMNode *aNode = [item objectForKey:WebElementDOMNodeKey];
	
	if (nil == aNode)		// nothing found, no point in continuing
	{
		// Be sure any pagelet and inline image is deselected
		[[self webViewController] setSelectedPageletHTMLElement:nil];
		[self setSelectedPagelet:nil];
		[self selectInlineIMGNode:nil container:nil];
		return;
	}
	
	if ([[aNode nodeName] isEqualToString:@"IMG"] && ![[aNode className] isEqualToString:kKTInternalImageClassName])
	{
		KTHTMLTextBlock *textBlock = [[[self webViewController] mainWebViewComponent] textBlockForDOMNode:aNode];
		
		// did we click on an image in a block of editable text, or on a photo (like a photo page/pagelet)
		if (textBlock || [DOMNode isImageFromDOMNodeClass:[[textBlock DOMNode] className]])
		{
			if (textBlock)
			{
				// we're here for instance if we clicked on an image in a pagelet or photo page
				
				
				[self selectInlineIMGNode:aNode container:[textBlock HTMLSourceObject]];
				[[self webViewController] setSelectedPageletHTMLElement:nil];
				[self setSelectedPagelet:nil];
			}
			
			// FIXME: Clicking on a photo page/pagelet has no effect without this
			/*
			else if ([container isKindOfClass:[KTPage class]])	// image in a page, select that detail.	(An image in a pagelet has to put image inspector along with pagelet)
			{
				// clicked on an image in a page
				[[self webViewController] setSelectedPageletHTMLElement:nil];
				[self setSelectedPagelet:nil];
				[self selectInlineIMGNode:nil container:nil];	// deselect any inline image
				[[NSNotificationCenter defaultCenter] postNotificationName:kKTItemSelectedNotification object:itemToEdit];
			}
			else if ([container isKindOfClass:[KTPagelet class]])	// image in a pagelet, select that pagelet
			{
				[[self webViewController] setSelectedPageletHTMLElement:selectedNode];
				// TODO: I need to be saving the pagelet, and then figuring out the pagelet element, and saving that, so it will survive across reloads!
				
				[[NSNotificationCenter defaultCenter] postNotificationName:kKTItemSelectedNotification object:container];
			}
			else
			{
				OFF((@"Clicked on an image, but not doing anything special"));
			}*/
		}
		else
		{
			OFF((@"You clicked on some other kind of image -- jump to pagelet checking"));
			// Total hack -- try to act as if we clicked elsewhere, like a pagelet.
			goto clickedOnPagelet;
		}
	}
	else
	{
clickedOnPagelet:
		[self selectInlineIMGNode:nil container:nil];	// deselect any inline image regardless of what's selected now
		
		// Now see if this is a click anywhere in a pagelet
		DOMHTMLElement *pageletElement = [self pageletElementEnclosing:aNode];
		
		if (nil != pageletElement)
		{
			KTPagelet *pagelet = [self pageletEnclosing:aNode];
			
			KTPage *selectedPage = [[self siteOutlineController] selectedPage];
			if ([[selectedPage pagelets] containsObject:pagelet])
			{				
				[[self webViewController] setSelectedPageletHTMLElement:pageletElement];
				// TODO: I need to be saving the pagelet, and then figuring out the pagelet element, and saving that, so it will survive across reloads!
				
				[[NSNotificationCenter defaultCenter] postNotificationName:kKTItemSelectedNotification object:pagelet];
			}
			else if (nil != pagelet)
			{
				[[self webViewController] setSelectedPageletHTMLElement:nil];
				[self setSelectedPagelet:nil];
				NSString *plugin = [[pagelet plugin] pluginPropertyForKey:@"KTPluginName"];
				if (nil == plugin) NSLog(@"Nil KTPluginName: %@", [pagelet plugin]);
				NSString *desc = [NSMutableString stringWithString:plugin];
				NSString *titleHTML = [pagelet titleHTML];
				if (nil != titleHTML && ![titleHTML isEqualToString:@""] && ![titleHTML isEqualToString:[[pagelet plugin] pluginPropertyForKey:@"KTPluginUntitledName"]])
				{
					desc = [NSString stringWithFormat:NSLocalizedString(@"%@ %@%@%@", @"format to show type of pagelet and its title, e.g. RSS Feed 'Cat Daily Digest'"),
						desc, leftDoubleQuote, [titleHTML stringByConvertingHTMLToPlainText], rightDoubleQuote];
				}
				KTPage *owningPage = [pagelet page];
				
				NSString *containingPageDescription = [owningPage isRoot]
					? NSLocalizedString(@"the home page",@"fragment describing homepage")
					: [NSString stringWithFormat:NSLocalizedString(@"an enclosing container page, %@%@%@",@"fragment describing a particular page"), leftDoubleQuote, [owningPage titleText], rightDoubleQuote];
				
				[[self confirmWithWindow:[self window]
							silencingKey:@"ShutUpCantSelect"
							   canCancel:YES OKButton:NSLocalizedString(@"Select",@"Button title")
								 silence:NSLocalizedString(@"Always select containing page", @"")
								   title:NSLocalizedString(@"Cannot Select Pagelet From This Page",@"alert title (capitalized)")
								  format:NSLocalizedString(@"The item you clicked on, %@, is copied from %@. Please select that page to edit this pagelet.",@""),
					desc, containingPageDescription]
					selectOwnerPageAndPageletRetainedElement:((DOMHTMLElement *)[pageletElement retain])];	// leaking on purpose
				//				[KSSilencingConfirmSheet alertWithWindow:[self window]
				//											silencingKey:@"ShutUpCantSelect"
				//													 title:NSLocalizedString(@"Cannot Select Pagelet from This Page", @"")
				//													format:NSLocalizedString(@"The item you clicked on, %@, is copied from an enclosing container page, %@%@%@. Please select that page to edit this pagelet.",@""), desc, leftDoubleQuote, containingPageTitleText, rightDoubleQuote];
			}
		}
		else	// clicked somewhere else ...
		{
			[[self webViewController] setSelectedPageletHTMLElement:nil];	// not a pagelet, deselect any pagelet
			[self setSelectedPagelet:nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:kKTItemSelectedNotification object:[[self siteOutlineController] selectedPage]];

			//DOMHTMLElement *node = [aNode firstSelectableParentNode];
			OFF((@"Clicked in this node:%@", ([node respondsToSelector:@selector(outerHTML)] ? [node outerHTML] : node) ));

			// see if we need to clear the inlineImage inspector
			if ( nil != [self selectedInlineImageElement]
				 && [[[KTInfoWindowController sharedControllerWithoutLoading] currentSelection] 
					isEqual:[self selectedInlineImageElement]] )
			{
				[[NSNotificationCenter defaultCenter] postNotificationName:kKTItemSelectedNotification
																	object:[[[self selectedInlineImageElement] container] page]];			
			}
			else
			{

			}
		}
	}
}



/*!	This is my own delegate method for dealing with a DOUBLE click.
	For editing a chunk of Raw HTML.

	Will this get the single click message too?  What happens if link panel is visible?

Note that this method is called AFTER the webview handles the click.
*/
- (void)webView:(WebView *)sender doubleClickAtCoordinates:(NSPoint)aPoint modifierFlags:(unsigned int)modifierFlags
{
	NSDictionary *item = [sender elementAtPoint:aPoint];
	DOMNode *aNode = [item objectForKey:WebElementDOMNodeKey];
	
	DOMHTMLElement *selectedNode = [aNode firstSelectableParentNode];
	
	// only process if we didn't click in editable text or a text field/text area
	if ( ![self isEditableElement:selectedNode] && ![[aNode nodeName] isEqualToString:@"TEXTAREA"]  && ![[aNode nodeName] isEqualToString:@"INPUT"] )
	{
		// Now see if this is a click anywhere in a pagelet
		DOMHTMLElement *htmlElementElement = [self elementOfClass:@"HTMLElement" enclosing:aNode];

		if (nil != htmlElementElement)
		{
			NSString *divID = [htmlElementElement idName];
			
			divID = [[divID componentsSeparatedByString:@"-"] lastObject];
			
			// Fetch the pagelet object
			// peform fetch
			NSManagedObjectContext *context = [[self document] managedObjectContext];
			KTAbstractElement *foundKTElement = [context pluginWithUniqueID:divID];
			
			// extract result
			if (foundKTElement)
			{
				
				[[self document] editSourceObject:foundKTElement keyPath:@"html" isRawHTML:YES];

			}
		}
		else
		{
			// Now see if this is a click anywhere in a pagelet
			DOMHTMLElement *pageletElement = [self pageletElementEnclosing:aNode];
			
			if (nil != pageletElement)	// show inspector
			{
				[self showInfo:YES];
			}
		}
	}
}

- (void)selectInlineIMGNode:(DOMNode *)aNode container:(KTAbstractElement *)aContainer
{
	if (aNode && [aNode isKindOfClass:[DOMHTMLImageElement class]])
	{
		// Ignore non svxmedia:// URLs
		NSString *src = [(DOMHTMLImageElement *)aNode src];
		if (src)
		{
			NSURL *URL = [NSURL URLWithString:src];
			if ([[URL scheme] isEqualToString:@"svxmedia"])
			{
				KTInlineImageElement *element = [[self webViewController] inlineImageElementForNode:(DOMHTMLImageElement *)aNode
																						  container:aContainer];
				
				[[NSNotificationCenter defaultCenter] postNotificationName:kKTItemSelectedNotification object:element];
			}
		}
	}
}

/*!	Open up editor window.	I may want to have a menu action for dealing with this so we don't need a double-click,
but the only trick is -- how to display a highlight?
*/

- (WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request
{
	return nil;
}

- (void)webViewShow:(WebView *)sender
{
}



- (void)webView:(WebView *)sender mouseDidMoveOverElement:(NSDictionary *)elementInformation modifierFlags:(unsigned int)modifierFlags
{
	NSString *leftDoubleQuote = NSLocalizedString(@"\\U201C", "left double quote");
	NSString *rightDoubleQuote = NSLocalizedString(@"\\U201D", "right double quote");

	NSString *title = [elementInformation objectForKey:WebElementLinkTitleKey];
	NSString *altText = [elementInformation objectForKey:WebElementImageAltStringKey];
	NSURL *URL = [elementInformation objectForKey:WebElementLinkURLKey];

	if (!KSISNULL(title) && ![title isEqualToString:@""])
	{
		OBASSERT([title isKindOfClass:[NSString class]]);   /// The previous code did this check, I assume it was to
        [self setStatusField:title];                        /// test for NSNull. Mike.
	}
	else if (URL)
	{
		NSURL *relativeURL = [URL URLRelativeToURL:[[[self webViewController] page] URL]];
		NSString *relativePath = [relativeURL relativePath];
        
        NSString *urlString = @"";
        if ([[URL scheme] isEqualToString:@"applewebdata"] || [relativePath hasPrefix:kKTPageIDDesignator])
		{
			KTPage *linkedPage = [[[self document] documentInfo] pageWithPreviewURLPath:[URL path]];
			if (nil != linkedPage)
			{
				if ([linkedPage isRoot])
				{
					urlString = NSLocalizedString(@"Home", "Home Page");
				}
				else
				{
					urlString = [linkedPage titleText];
				}
			}
			else
			{
				urlString = [URL lastPathComponent];
			}
		}
		else
		{
			urlString = [URL absoluteString];
		}
		if ([[URL scheme] isEqualToString:@"mailto"])
		{
			[self setStatusField:urlString];
		}
		else if ([[URL scheme] isEqualToString:@"media"])
		{
			[self setStatusField:NSLocalizedString(@"On published site, clicking on image will view full-size image",@"")];
		}
		else
		{
			[self setStatusField:[NSString stringWithFormat:@"%@ %@%@%@", NSLocalizedString(@"Go to", "Go to (followed by URL)"), leftDoubleQuote, urlString, rightDoubleQuote]];
		}
	}
	else if (altText && ![altText isEqualToString:@""])
	{
		[self setStatusField:[NSString stringWithFormat:@"%@ %@%@%@", NSLocalizedString(@"Image ", "Image "), leftDoubleQuote, altText, rightDoubleQuote]];
	}
	else
	{
		[self setStatusField:@""];
	}
}

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)elementInformation defaultMenuItems:(NSArray *)defaultMenuItems
{
	NSString *leftDoubleQuote = NSLocalizedString(@"\\U201C", "left double quote");
	NSString *rightDoubleQuote = NSLocalizedString(@"\\U201D", "right double quote");

	NSMutableArray *array = [NSMutableArray array];
	
	OFF((@"element ctrl-clicked on: %@", elementInformation));
		
	// context has changed, first update base info
	[self setContextElementInformation:[[elementInformation mutableCopy] autorelease]];
	
	BOOL elementIsSelected = [[elementInformation valueForKey:WebElementIsSelectedKey] boolValue];
	
	if ( nil != [elementInformation valueForKey:@"WebElementDOMNode"] )
	{
		DOMNode *node = [elementInformation valueForKey:@"WebElementDOMNode"];
		DOMHTMLElement *selectedNode = [node firstSelectableParentNode];
		
		// first, if the element is editable and linkable, add a Create/Edit Link... item
		if ( elementIsSelected
			 && [self isEditableElement:selectedNode]
			 && [DOMNode isLinkableFromDOMNodeClass:[selectedNode className]] )
		{
			// add selectedDOMRange to elementInformation
			NSMutableDictionary *elementDictionary = [NSMutableDictionary dictionaryWithDictionary:[self contextElementInformation]];
			
			DOMRange *selectedDOMRange = [sender selectedDOMRange];
			if ( nil != selectedDOMRange )
			{
				[elementDictionary setObject:selectedDOMRange forKey:KTSelectedDOMRangeKey];
			}
			else
			{
				// selectedDOMRange will be nil when a pre-existing link is ctrl-clicked
				// without making a selection. in that case, assume we want to work on the entire node
				DOMDocument *document = [[selectedDOMRange startContainer] ownerDocument];
				DOMRange *range = [document createRange];
				[range selectNode:node];
				[elementDictionary setObject:range forKey:KTSelectedDOMRangeKey];
			}
			
			[self setContextElementInformation:[NSMutableDictionary dictionaryWithDictionary:elementDictionary]];
			
			// start with an Edit or Create link menuitem
			if ( nil != [elementInformation objectForKey:@"WebElementLinkURL"] )
			{
				// the selection contains a link, so let's assume we want to edit it
				NSMenuItem *editLinkItem = [[NSMenuItem alloc] initWithTitle:EDIT_LINK_MENUITEM_TITLE
																	  action:@selector(performShowLinkPanel:)
															   keyEquivalent:@""];
				[editLinkItem setRepresentedObject:nil];
				[editLinkItem setTarget:nil];
				[array addObject:editLinkItem];
				[editLinkItem release];
			}
			else
			{
				// no link included, maybe we want to add one
				NSMenuItem *createLinkItem = [[NSMenuItem alloc] initWithTitle:CREATE_LINK_MENUITEM_TITLE
																		action:@selector(performShowLinkPanel:)
																 keyEquivalent:@""];
				[createLinkItem setRepresentedObject:nil];
				[createLinkItem setTarget:nil];
				[array addObject:createLinkItem];
				[createLinkItem release];
			}
		}
		
		// add Edit Raw HTML...
		if ( ((nil == gRegistrationString) || gIsPro) 
			 && (selectedNode == [[[self webViewController] currentTextEditingBlock] DOMNode]	// is this currently focused editable text?
				 || [DOMNode isHTMLElementFromDOMNodeClass:[selectedNode className]] )
			  )
		{
			NSString *title = NSLocalizedString(@"Edit Raw HTML...", "Edit Raw HTML... MenuItem");
			NSMenuItem *editRawHTMLItem = [[NSMenuItem alloc] initWithTitle:title
																	 action:@selector(editRawHTMLInSelectedBlock:) 
															  keyEquivalent:@""];
			
			if ( nil == gRegistrationString )
			{
				[[NSApp delegate] setMenuItemPro:editRawHTMLItem];
			}
			[editRawHTMLItem setRepresentedObject:nil];
			[editRawHTMLItem setTarget:nil];
			[array addObject:editRawHTMLItem];
			[editRawHTMLItem release];
		}
		
		// next, trim the default menu items to a reasonable set and add to menu
		// if we're clicked on an Image, don't add any of the default menu
		if ( elementIsSelected
			 && ![node isKindOfClass:[DOMHTMLImageElement class]]
			 && (nil != [self contextElementInformation]) )
		{
			NSMutableArray *copyOfDefaultMenuItems = [[defaultMenuItems mutableCopy] autorelease];
			NSEnumerator *e = [defaultMenuItems objectEnumerator];
			NSMenuItem *menuItem;
			while ( menuItem = [e nextObject] )
			{
				BOOL shouldRemove = NO;
				
				NSString *actionString = NSStringFromSelector([menuItem action]);
				if ( [actionString isEqualToString:@"reload:"] )
				{
					shouldRemove = YES;
				}
				else if ( [actionString isEqualToString:@"submenuAction:"] )
				{
					// remove all submenus except Spelling and Find
					// this is a bit of a hack since it depends on string comparisons
					NSString *spellingTitle = NSLocalizedString(@"Spelling", "Spelling MenuItem"); // must match WebKit's
					NSString *findTitle = NSLocalizedString(@"Find", "Find MenuItem"); // must match WebKit's
					if ( ![[menuItem title] isEqualToString:spellingTitle]
						 && ![[menuItem title] isEqualToString:findTitle] )
					{
						shouldRemove = YES;
					}
				}
				
				if ( shouldRemove )
				{
					[copyOfDefaultMenuItems removeObject:menuItem];
				}
			}
			if ( [copyOfDefaultMenuItems count] > 0 )
			{
				if ( [array count] > 0 && ![(NSMenuItem *)[array lastObject] isSeparatorItem] )
				{
					[array addObject:[NSMenuItem separatorItem]];
				}
				[array addObjectsFromArray:copyOfDefaultMenuItems];
			}
		}
		
		// is element a pagelet?
		KTPagelet *pagelet = [self pageletEnclosing:node];
		if ( nil != pagelet )
		{
			if ( [array count] > 0 && ![(NSMenuItem *)[array lastObject] isSeparatorItem] )
			{
				[array addObject:[NSMenuItem separatorItem]];
			}
			
			KTPage *selectedPage = [[self siteOutlineController] selectedPage];
			if ( [[selectedPage pagelets] containsObject:pagelet] )
			{
				[self setSelectedPagelet:pagelet];
				
				NSMenuItem *deletePageletItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Delete Pagelet", "Delete Pagelet MenuItem")
																		   action:@selector(deletePagelets:)
																	keyEquivalent:@""];
				[deletePageletItem setRepresentedObject:nil];
				[deletePageletItem setTarget:nil];
				[array addObject:deletePageletItem];
				[deletePageletItem release];
				
				// if on selectedPage's calloutsList, put up Move to Sidebar
				NSMenuItem *moveMenuItem = nil;
				if ( [[selectedPage callouts] containsObject:pagelet] 
                     && [selectedPage includeSidebar] )
				{
					moveMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Move to Sidebar", "Move to Sidebar MenuItem")
															  action:@selector(movePageletToSidebar:)
													   keyEquivalent:@""];
					[moveMenuItem setTarget:selectedPage];
					[moveMenuItem setRepresentedObject:pagelet];
				}
				// else, if on selectedPage's sidebarsList, put up Move to Callout
				else if ([pagelet location] == KTSidebarPageletLocation && [selectedPage includeCallout])
				{
					moveMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Move to Callout", "Move to Callout MenuItem")
															  action:@selector(movePageletToCallouts:)
													   keyEquivalent:@""];
					[moveMenuItem setTarget:selectedPage];
					[moveMenuItem setRepresentedObject:pagelet];
				}
				if (nil != moveMenuItem)
				{
					[array addObject:moveMenuItem];
					[moveMenuItem release];
				}
			}
			else	// show in menu reason why pagelet can't be manipulated
			{
				KTPage *owningPage = [pagelet page];
				
				NSString *menuTitle = [owningPage isRoot]
					? NSLocalizedString(@"Pagelet owned by home page",
										@"menu item showing that pagelet canot be manipulated")
					: [NSString stringWithFormat:NSLocalizedString(@"Pagelet owned by page %@%@%@",
																   @"menu item showing that pagelet canot be manipulated"),
						leftDoubleQuote, [owningPage titleText], rightDoubleQuote];
				NSMenuItem *noOpPageletItem
					= [[NSMenuItem alloc]
						initWithTitle:menuTitle
							   action:nil
						keyEquivalent:@""];
				[noOpPageletItem setRepresentedObject:nil];
				[noOpPageletItem setTarget:nil];
				[array addObject:noOpPageletItem];
				[noOpPageletItem release];
			}
		}
		
		// See if it's summary
		
		if (selectedNode)
		{
			KTHTMLTextBlock *textBlock = [[[self webViewController] mainWebViewComponent] textBlockForDOMNode:selectedNode];
			
			if ([textBlock isKindOfClass:[KTSummaryWebViewTextBlock class]])
			{
				if ( [array count] > 0 && ![(NSMenuItem *)[array lastObject] isSeparatorItem] )
				{
					[array addObject:[NSMenuItem separatorItem]];
				}
				KTPage *theSummarizedPage = [textBlock HTMLSourceObject];
				
				NSMenuItem *theSummaryMenuItem = nil;
				SEL theAction;
				NSString *menuTitle = nil;
				if ([theSummarizedPage customSummaryHTML])
				{
					menuTitle = NSLocalizedString(@"Remove Custom Summary of Page...",@"contextual menu item");
					theAction = @selector(unOverrideSummary:);
				}
				else
				{
					menuTitle = NSLocalizedString(@"Custom Summary for Index",@"contextual menu item");
					theAction = @selector(overrideSummary:);
				}
				theSummaryMenuItem = [[NSMenuItem alloc] initWithTitle:menuTitle
																action:theAction
														 keyEquivalent:@""];
				[theSummaryMenuItem setRepresentedObject:theSummarizedPage];
				[theSummaryMenuItem setTarget:textBlock];
				[array addObject:theSummaryMenuItem];
				[theSummaryMenuItem release];
			}
		}
	}	
	
	if (0 == [array count])
	{
		return nil;	// NO element so just return nil -- prevent exception case 9144
	}
	
	// don't end menu with separator
	if ( [(NSMenuItem *)[array lastObject] isSeparatorItem] )
	{
		[array removeLastObject];
	}
	
	return [NSArray arrayWithArray:array];
}





/*!
@method webView:willPerformDragDestinationAction:forDraggingInfo:
 @abstract Informs that WebView will perform a drag destination action
 @param webView The WebView sending the delegate method
 @param action The drag destination action
 @param draggingInfo The dragging info of the drag
 @discussion This method is called after the last call to webView:dragDestinationActionMaskForDraggingInfo: after something is dropped on a WebView.
 This method informs the UI delegate of the drag destination action that WebView will perform.
 */
- (void)webView:(WebView *)inWebView
willPerformDragDestinationAction:(WebDragDestinationAction)action
forDraggingInfo:(id <NSDraggingInfo>)draggingInfo
{
	OFF((@"%@, %d %@", NSStringFromSelector(_cmd), action, draggingInfo));
	
	// Dragging location is in window coordinates.
	// location is converted to webview coordinates
	NSPoint location = [inWebView convertPoint:[draggingInfo draggingLocation] fromView:nil];
	NSDictionary *item = [inWebView elementAtPoint:location];
	DOMNode *aNode = [item objectForKey:WebElementDOMNodeKey];
	
	KTHTMLTextBlock *textBlock = [[[self webViewController] mainWebViewComponent] textBlockForDOMNode:aNode];
	if (textBlock && textBlock != [[self webViewController] currentTextEditingBlock])	// avoid calling this again if we already have a selection since that clones the contents
	{
		[[self webViewController] setCurrentTextEditingBlock:textBlock];
	}
	else
	{
		OFF((@"Unable to find selectable node enclosing %@", aNode));
	}
}

- (void)webView:(WebView *)sender willPerformDragSourceAction:(WebDragSourceAction)action
	  fromPoint:(NSPoint)point
 withPasteboard:(NSPasteboard *)pasteboard
{
	OFF((@"%@, %d %@", NSStringFromSelector(_cmd), action, NSStringFromPoint(point)));
}

- (unsigned)webView:(WebView *)inWebView dragDestinationActionMaskForDraggingInfo:(id <NSDraggingInfo>)draggingInfo
{
	OFF((@"%@, %@", NSStringFromSelector(_cmd), draggingInfo));	// caution logging -- it's called a lot!
	return WebDragDestinationActionAny;
}

- (unsigned)webView:(WebView *)inWebView dragSourceActionMaskForPoint:(NSPoint)inPoint
{
	OFF((@"%@ %@", NSStringFromSelector(_cmd), NSStringFromPoint(inPoint)));
	return WebDragSourceActionAny;
}

#pragma mark -
#pragma mark WebUIDelegate - Support

/*!	Find the node, if any, that has a class of "pagelet" in its class name

class has pagelet, ID like k-###	(the k- is to be recognized elsewhere)
*/


- (DOMHTMLElement *)elementOfClass:(NSString *)aDesiredClass enclosing:(DOMNode *)aNode;
{
	DOMHTMLElement *foundDiv = nil;
	
	if ([aNode isKindOfClass:[DOMCharacterData class]])
	{
		aNode = [aNode parentNode];	// get up to the element
	}
	while (nil != aNode && [aNode isKindOfClass:[DOMHTMLElement class]] && ![aNode isKindOfClass:[DOMHTMLBodyElement class]])
	{
		if (nil == foundDiv)
		{
			NSString *theClass = [aNode className];
			NSArray *classes = [theClass componentsSeparatedByWhitespace];
			if ([classes containsObject:aDesiredClass])
			{
				foundDiv = (DOMHTMLElement *)aNode;				  // save for later
				break;
			}
		}
		// Now continue up the chain to the parent.
		aNode = [aNode parentNode];
	}
	return foundDiv;
}

- (DOMHTMLElement *)pageletElementEnclosing:(DOMNode *)aNode;
{
	return [self elementOfClass:@"pagelet" enclosing:aNode];
}

- (KTPagelet *)pageletEnclosing:(DOMNode *)aNode;
{
	KTPagelet *result = nil;
	DOMHTMLElement *foundDiv = [self pageletElementEnclosing:aNode];
	
	if (nil != foundDiv)
	{
		NSString *divID = [foundDiv idName];
		
		// NB: we expect a 1 character prefix on divID (the pagelet DIV)
		// which we have to strip before passing to Core Data
		// pagelet DIVs are built from the various pagelet templates
		
		if ([divID length] > 2)
		{
			divID = [divID substringFromIndex:2];
			
			// Fetch the pagelet object
			// peform fetch
			NSManagedObjectContext *context = [[self document] managedObjectContext];
			NSError *fetchError = nil;
			NSArray *fetchedObjects = [context objectsWithEntityName:@"Pagelet"
														   predicate:[NSPredicate predicateWithFormat:@"uniqueID like %@", divID]
															   error:&fetchError];	
			// extract result
			if ( (nil != fetchedObjects) && ([fetchedObjects count] == 1) )
			{
				result = [fetchedObjects objectAtIndex:0];
			}
		}
	}
	return result;
}


#pragma mark in-line link editor methods

- (NSWindow *)linkPanel { return oLinkPanel; }

- (void)linkPanelDidLoad
{
	[oLinkView setDelegate:self];
	// tweak the look
	[oLinkControlsBox setDrawsGradientBackground:NO];
	//[oLinkControlsBox setGradientStartColor:[NSColor colorWithCalibratedWhite:0.92 alpha:1.0]];
	//[oLinkControlsBox setGradientEndColor:[NSColor colorWithCalibratedWhite:0.82 alpha:1.0]];
	[oLinkControlsBox setBackgroundColor:[NSColor colorWithCalibratedWhite:0.95 alpha:1.0]];
	[oLinkControlsBox setBorderColor:[NSColor lightGrayColor]];
	[oLinkControlsBox setTitleColor:[NSColor whiteColor]];
	[oLinkControlsBox setDrawsFullTitleBar:NO];
	[oLinkControlsBox setBorderWidth:1.0];
	
	[[oLinkControlsBox window] setDelegate:self];
}

- (id)userInfoForLinkSource:(KTLinkSourceView *)link
{
	return [[self document] documentInfo];
}

- (NSPasteboard *)linkSourceDidBeginDrag:(KTLinkSourceView *)link
{
	NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
	[pboard declareTypes:[NSArray arrayWithObject:kKTLocalLinkPboardType] owner:self];
	[pboard setString:@"LocalLink" forType:kKTLocalLinkPboardType];
	
	return pboard;
}

- (void)linkSourceDidEndDrag:(KTLinkSourceView *)link withPasteboard:(NSPasteboard *)pboard
{
	NSMutableDictionary *info = [self contextElementInformation];
	if (info)
	{
		// set up a link to the local page
		NSString *pageID = [pboard stringForType:kKTLocalLinkPboardType];
		if ( (pageID != nil) && ![pageID isEqualToString:@""] )
		{
			KTPage *target = [KTPage pageWithUniqueID:pageID inManagedObjectContext:[[self document] managedObjectContext]];
			if ( nil != target )
			{
				NSString *titleText = [target titleText];
				if ( (nil != titleText) && ![titleText isEqualToString:@""] )
				{
					[oLinkLocalPageField setStringValue:titleText];
					[oLinkDestinationField setStringValue:@""];
					[oLinkLocalPageField setHidden:NO];
					[oLinkDestinationField setHidden:YES];
					
					[info setValue:[NSString stringWithFormat:@"%@%@", kKTPageIDDesignator, pageID] forKey:@"KTLocalLink"];
					[oLinkView setConnected:YES];
					
				}
			}
		}
	}
	//	NO, DON'T CLOSE THE LINK PANEL WHEN YOU DRAG.	[oLinkPanel orderOut:self];
}

- (IBAction)performShowLinkPanel:(id)sender
{
	[self performSelector:@selector(showLinkPanel:) withObject:sender afterDelay:0.0];
}

- (IBAction)showLinkPanel:(id)sender
{
	BOOL localLink = NO;		// override if it's a local link
	NSString *theLinkString = nil;
	
	[oLinkOpenInNewWindowSwitch setState:NSOffState];
	
	// populate with context information
	NSMutableDictionary *info = [[self contextElementInformation] retain];
	if (info)
	{
		DOMNode *node = [info objectForKey:WebElementDOMNodeKey];
		DOMRange *selectedRange = [[[self webViewController] webView] selectedDOMRange];
		
        
		// Hunt down the anchor to edit
		DOMNode *possibleAnchor = [selectedRange commonAncestorContainer];
        if (![possibleAnchor isKindOfClass:[DOMHTMLAnchorElement class]])
        {
            possibleAnchor = [possibleAnchor parentNode];
        }
        
		
		if ([possibleAnchor isKindOfClass:[DOMHTMLAnchorElement class]] && [(DOMHTMLAnchorElement *)possibleAnchor href])
		{
			theLinkString = [(DOMHTMLAnchorElement *)possibleAnchor href];
			if ([theLinkString hasPrefix:@"applewebdata:"])
			{
				theLinkString = [theLinkString lastPathComponent];
				// some absolute page link.	 Restore the leading slash
				theLinkString = [@"/" stringByAppendingString:theLinkString];
			}
			NSRange wherePageID = [theLinkString rangeOfString:kKTPageIDDesignator];
			if (NSNotFound != wherePageID.location)
			{
				[info setValue:[theLinkString lastPathComponent] forKey:@"KTLocalLink"]; // mark as local link so we preserve it
				NSString *uid = [theLinkString substringFromIndex:NSMaxRange(wherePageID)];
				KTPage *targetPage = [KTPage pageWithUniqueID:uid inManagedObjectContext:[[self document] managedObjectContext]];
				theLinkString = [targetPage titleText];
				localLink = YES;
			}
            
            // Since we're editing a link, select it
            [selectedRange selectNode:possibleAnchor];
			
			// Yikes, calling this invokes webViewDidChangeSelection, which calls setContextElementInformation
            [[[self webViewController] webView] setSelectedDOMRange:selectedRange affinity:NSSelectionAffinityDownstream];
			// So restore it to what we had
			[self setContextElementInformation:info];
		}
		else if ( nil != node )
		{
			// examine selectedRange for an e-mail address
			NSString *string = [selectedRange toString];
			if ( [string isValidEmailAddress] )
			{
				theLinkString = [NSString stringWithFormat:@"mailto:%@", string];
			}
			else
			{
				// Try to populate from frontmost Safari URL
				NSURL *safariURL = nil;
				NSString *safariTitle = nil;	// someday, we could populate the link title as well!
				[NSAppleScript getWebBrowserURL:&safariURL title:&safariTitle source:nil];
				if (safariURL)
				{
					theLinkString = [safariURL absoluteString];
				}
			}
		}
		
		[oLinkView setConnected:(nil != theLinkString)];
		
		if (nil == theLinkString)
		{
			theLinkString = @"";
		}
		if (localLink)
		{
			[oLinkLocalPageField setStringValue:theLinkString];
			[oLinkDestinationField setStringValue:@""];
		}
		else
		{
			[oLinkLocalPageField setStringValue:@""];
			[oLinkDestinationField setStringValue:theLinkString];	// we were unescaping this -- wrong!
		}
		[oLinkLocalPageField setHidden:!localLink];
		[oLinkDestinationField setHidden:localLink];
		
		// set oLinkOpenInNewWindowSwitch
		if ( nil != [info objectForKey:WebElementDOMNodeKey] )
		{
			DOMNode *parentNode = [(DOMNode *)[info objectForKey:WebElementDOMNodeKey] parentNode];
			if ( [parentNode isKindOfClass:[DOMHTMLAnchorElement class]] )
			{
				NSString *target = [(DOMHTMLAnchorElement *)parentNode target];
				if ( [target isEqualToString:@"_blank"] )
				{
					[oLinkOpenInNewWindowSwitch setState:NSOnState];
				}
			}
		}
		
		// set top left corner of window to top of selectedTextRect in screen coordinates
		NSPoint topLeftCorner = [self linkPanelTopLeftPointForSelectionRect:mySelectionRect];
		NSPoint convertedWindowOrigin = [[self window] convertBaseToScreen:topLeftCorner];
		[oLinkPanel setFrameTopLeftPoint:convertedWindowOrigin];
		
		// make it a child window, set focus on the link, and display
		[[self window] addChildWindow:oLinkPanel ordered:NSWindowAbove];
		[oLinkPanel makeKeyAndOrderFront:nil]; // we do makeKey so that textfield gets focus
	}
	else
	{
		NSLog(@"Unable to show link panel; reselect text in Web View.");
	}
	[info release];
}

- (NSString *)removeLinkWithDOMRange:(DOMRange *)selectedRange
{
	// Find all the links in the selection
	DOMNode *ancestor = [selectedRange commonAncestorContainer];
	NSMutableArray *anchors = [NSMutableArray arrayWithArray:[ancestor anchorElements]];
	
	if ([anchors count] == 0)     // For small selections, fallback to see if the parent is an anchor
	{
		DOMNode *ancestorParent = [ancestor parentNode];
		if ( [ancestorParent isKindOfClass:[DOMHTMLAnchorElement class]] )
		{
			[anchors addObject:ancestorParent];
		}
	}
    
    
	// If more than 1 link is selected, you have a contextual menu problem, there should never be more than 1
	if ([anchors count] == 1)
	{
		// have the anchor's parent replace the anchor with the anchor's child
		DOMHTMLAnchorElement *anchor = [anchors objectAtIndex:0];
		DOMNode *anchorParent = [anchor parentNode];
		if ( [anchor hasChildNodes] )
		{
			DOMNode *child = [anchor firstChild];
			[[[self webViewController] webView] replaceNode:anchor withNode:child];
		}
		else
		{
			// not sure how it would be selectable without child text...
			[[DOMNode class] node:anchorParent removeChild:anchor];
		}
		return NSLocalizedString(@"Remove Link","ActionName: Remove Link");
	}
	else
	{
		OFF((@"selectedRange of anchor has more than one anchor, ignoring..."));
		return nil;
	}
}

/*  The process of creating a link is very simple: Crate the DOM nodes and then insert them using -replaceSelectionWithNode:
 *  WebKit will manage the undo/redo stuff for us.
 *		aString is the fallback text to use if there is no selection to replace. If nil, just use the text of the URL.
 */
- (NSString *)createLink:(NSString *)link desiredText:(NSString *)aString openLinkInNewWindow:(BOOL)openLinkInNewWindow
{
	// Preparation
    WebView *webView = [[self webViewController] webView];      OBASSERT(webView);
    DOMRange *selectedRange = [webView selectedDOMRange];
	if (selectedRange)
	{
		DOMNode *selectionStart = [selectedRange startContainer];   OBASSERT(selectionStart);
		DOMDocument *DOMDoc = [selectionStart ownerDocument];       OBASSERT(DOMDoc);
		
		
		// Create the link DOM nodes
		DOMHTMLAnchorElement *anchor = (DOMHTMLAnchorElement *)[DOMDoc createElement:@"a"];
		OBASSERT(anchor);   OBASSERT([anchor isKindOfClass:[DOMHTMLAnchorElement class]]);
		
		[anchor setHref:link];
		if (openLinkInNewWindow) [anchor setTarget:@"_blank"];
		if ([selectedRange startOffset] == [selectedRange endOffset])
		{
			NSString *textToInsert = (KSISNULL(aString) || [aString isEmptyString]) ? link : aString;
			DOMText *text = [DOMDoc createTextNode:textToInsert];
			[anchor appendChild:text];
		}
		else
		{
			[anchor appendChild:[selectedRange cloneContents]];
		}
		
		// Insert the link into the DOM
		[webView replaceSelectionWithNode:anchor];
		
		
		return NSLocalizedString(@"Add Link","Action Name: Add Link");
	}
	
	return nil;
}	

- (IBAction)clearLinkDestination:(id)sender;
{
	[oLinkLocalPageField setStringValue:@""];
	[oLinkDestinationField setStringValue:@""];
	[oLinkLocalPageField setHidden:YES];
	[oLinkDestinationField setHidden:NO];
	[oLinkView setConnected:NO];
	NSMutableDictionary *info = [self contextElementInformation];
	[info removeObjectForKey:@"KTLocalLink"];
}


- (void)closeLinkPanel
{
	[[self window] removeChildWindow:oLinkPanel];
	[oLinkPanel close];
}

- (IBAction)finishLinkPanel:(id)sender
{
	NSString *undoActionName = nil;
	
	// per Graham, check/set flag to stop recursion
	// due to selectionDidChange: calling back into createLink:
	if ( myIsLinkPanelClosing )
	{
		return;
	}
	myIsLinkPanelClosing = YES;
	
	@try
	{
		// grab our element info
		NSDictionary *info = [self contextElementInformation];
		OBASSERTSTRING((nil != info), @"contextElementInformation cannot be nil!");
		
		// have we set up a local link?
		if ( nil != [info valueForKey:@"KTLocalLink"] )
		{
			undoActionName = [self createLink:[info valueForKey:@"KTLocalLink"] desiredText:nil openLinkInNewWindow:[oLinkOpenInNewWindowSwitch state] == NSOnState];
		}
		else
		{
			NSString *value = [[oLinkDestinationField stringValue] stringByTrimmingFirstLine];
			value = [[value stringWithValidURLScheme]  stringByTrimmingFirstLine];
			
			if ( [value isEqualToString:@""]
				 || [value isEqualToString:@"http://"]
				 || [value isEqualToString:@"https://"]
				 || [value isEqualToString:@"ftp://"]
				 || [value isEqualToString:@"mailto:"] )
			{
				// empty field, remove the link
                undoActionName = [self removeLinkWithDOMRange:[info objectForKey:KTSelectedDOMRangeKey]];
			}
			else
			{
				// check URL and refuse to close if not valid.  We call the delegate method to test value.
				if (![self control:oLinkDestinationField textShouldEndEditing:nil])
				{
					NSBeep();
					NSLog(@"refusing to end editing");
					return;
				}
				
				// not empty, is there already an anchor in play?
				undoActionName = [self createLink:value desiredText:nil openLinkInNewWindow:[oLinkOpenInNewWindowSwitch state] == NSOnState];
			}
		}

		// update webview to reflect node changes
		[[NSNotificationCenter defaultCenter] postNotificationName:WebViewDidChangeNotification
                                                            object:[[self webViewController] webView]];	
		[self setContextElementInformation:nil];
		
		// label undo last
		if ( nil != undoActionName )
		{
			[[[[self webViewController] webView] undoManager] setActionName:undoActionName];
		}
	}
	@finally
	{
		// hide link panel
		[self closeLinkPanel];
		myIsLinkPanelClosing = NO;
	}
}

- (NSPoint)linkPanelTopLeftPointForSelectionRect:(NSRect)aSelectionRect
{
	NSWindow *window = [self window];
	NSScreen *screen  = [window screen];
	NSRect visibleFrame = [screen visibleFrame];
	
	float padding = 30; // eyeball
	float linkPanelWidth = 356; // from nib
	float linkPanelHeight = 101; // from nib
	float windowWidth = [window frame].size.width;
	
	float linkPanelOriginX;
	float linkPanelOriginY;
	if ( mySelectionRect.size.width > 0 )
	{
		if ( (mySelectionRect.origin.x + linkPanelWidth) > windowWidth )
		{
			linkPanelOriginX = windowWidth - linkPanelWidth - padding;
		}
		else
		{
			linkPanelOriginX = mySelectionRect.origin.x;
		}
		linkPanelOriginY = mySelectionRect.origin.y;
	}
	else
	{
		if ( (myLastClickedPoint.x + linkPanelWidth) > windowWidth )
		{
			linkPanelOriginX = windowWidth - linkPanelWidth - padding;
		}
		else
		{
			linkPanelOriginX = myLastClickedPoint.x;
		}
		linkPanelOriginY = myLastClickedPoint.y;
	}
	
	// keep it within the visibleFrame
	NSPoint linkPanelOrigin = NSMakePoint(linkPanelOriginX,linkPanelOriginY);
	
	NSPoint linkPanelOriginInScreen = [window convertBaseToScreen:NSMakePoint(linkPanelOriginX,linkPanelOriginY)];
	float linkPanelOriginXInScreen = linkPanelOriginInScreen.x;
	float linkPanelOriginYInScreen = linkPanelOriginInScreen.y;
	
	if ( (linkPanelOriginXInScreen + linkPanelWidth) > visibleFrame.size.width )
	{
		linkPanelOriginXInScreen = (visibleFrame.size.width - linkPanelWidth);
		linkPanelOriginInScreen = NSMakePoint(linkPanelOriginXInScreen,linkPanelOriginYInScreen);
		linkPanelOrigin = [window convertScreenToBase:linkPanelOriginInScreen];
	}
	
	if ( linkPanelOriginXInScreen < visibleFrame.origin.x )
	{
		linkPanelOriginXInScreen = visibleFrame.origin.x;
		linkPanelOriginInScreen = NSMakePoint(linkPanelOriginXInScreen,linkPanelOriginYInScreen);
		linkPanelOrigin = [window convertScreenToBase:linkPanelOriginInScreen];
	}
	
	if ( (linkPanelOriginYInScreen - linkPanelHeight) < visibleFrame.origin.y )
	{
		linkPanelOriginYInScreen = linkPanelOriginYInScreen + linkPanelHeight + aSelectionRect.size.height;
		linkPanelOriginInScreen = NSMakePoint(linkPanelOriginXInScreen,linkPanelOriginYInScreen);
		linkPanelOrigin = [window convertScreenToBase:linkPanelOriginInScreen];
	}
	
	return linkPanelOrigin; // in flipped coordinates
}

- (void)windowDidEscape:(NSWindow *)aWindow
{
	if ( aWindow == oLinkPanel )
	{
		// escape was pressed, close link panel without accepting changes
		[self closeLinkPanel];
	}
}

/*! accepts drop of WebURLsWithTitlesPboardType and NSURLPboardType, in that order */
- (BOOL)acceptDropOfURLsFromDraggingInfo:(id <NSDraggingInfo>)sender
{
	NSString *URLAsString = nil;
	NSString *title = nil;
	
	NSPasteboard *pboard = [sender draggingPasteboard];
	
	if ( [[pboard types] containsObject:@"WebURLsWithTitlesPboardType"] )
	{
		NSArray *URLsWithTitles = [pboard propertyListForType:@"WebURLsWithTitlesPboardType"];
		if	( [URLsWithTitles count] > 0 )
		{
			NSArray *URLsAsStrings = [URLsWithTitles objectAtIndex:0];
			NSArray *titles = [URLsWithTitles objectAtIndex:1];
			
			// we're only taking the first one
			/// These two were just blindly calling objectAtIndex:0 and getting an exception sometimes
			URLAsString = [URLsAsStrings firstObjectKS];
			title = [titles firstObjectKS];
		}
	}
	else if ( [[pboard types] containsObject:NSURLPboardType] )
	{
		NSURL *url = [NSURL URLFromPasteboard:pboard];
		URLAsString = [url absoluteString];
	}
	
	if ( (nil == URLAsString) || [URLAsString isEqualToString:@""] )
	{
		// we didn't find a useable URL string, not much we can do, bail
		NSBeep();
		NSLog(@"we didn't find a useable URL string");
		return NO;
	}
	
	NSURL *theURL = [NSURL URLWithUnescapedString:URLAsString];
	// filter out file:// URLs ... let webview handle it and insert any images
	if ( [[theURL scheme] isEqualToString:@"file"] )
	{
		OFF((@"dropping in a file: URL"));
		return NO;
	}

	if ( [[theURL scheme] isEqualToString:@"applewebdata"] )
	{
		NSRange wherePageID = [URLAsString rangeOfString:kKTPageIDDesignator];
		if (NSNotFound == wherePageID.location)
		{
			return NO;
		}
		URLAsString = [URLAsString substringFromIndex:wherePageID.location];	// new URL, just the page ID
	}
	
	if ([[theURL scheme] isEqualToString:@"svxmedia"]) return NO;
	
	
	if ( (nil == title) || [title isEqualToString:@""] )
	{
		// if no title, set it to the body of the URL, no scheme
		NSString *scheme = [theURL scheme];
		if ( nil != scheme )
		{
			NSRange schemeRange = [URLAsString rangeOfString:scheme];
			title = [URLAsString substringFromIndex:(schemeRange.length+1)];
		}
		else
		{
			title = URLAsString;
		}
	}
	
	// ok, at this point we should have some sort of useable url and title
	
	// figure out where we are in the WebHTMLView
	Class WebHTMLView = NSClassFromString(@"WebHTMLView");
	NSView *documentView = [[[[[self webViewController] webView] mainFrame] frameView] documentView];
	OBASSERTSTRING([documentView isKindOfClass:[WebHTMLView class]], @"documentView should be a WebHTMLView");
	
	// determine dragCaretDOMRange (DOMRange, of 0 length, where drop will go, between chars)
	id bridge = [documentView _bridge];
	DOMRange *dragCaretDOMRange = nil;
	if ([bridge respondsToSelector:@selector(dragCaretDOMRange)])
	{
		dragCaretDOMRange = (DOMRange *)[bridge dragCaretDOMRange];
	}
	
	// get our currently selected range
	DOMRange *selectedDOMRange = [[[self webViewController] webView] selectedDOMRange];
	
	// if selectedDOMRange is nil, insert a new text node at caretPosition
	if ( nil == selectedDOMRange )
	{
		[self insertText:title href:URLAsString inRange:dragCaretDOMRange atPosition:[dragCaretDOMRange startOffset]];
		[[[[self webViewController] webView] undoManager] setActionName:NSLocalizedString(@"Insert Link","Action Name: Insert Link")];
		return YES;
	}
	
	// no, we have a selection, do some range checking
	short startToStart = [selectedDOMRange compareBoundaryPoints:DOM_START_TO_START :dragCaretDOMRange];
	short endToEnd = [selectedDOMRange compareBoundaryPoints:DOM_END_TO_END :dragCaretDOMRange];
	// -1 = A is before B
	//	 1 = A is after B
	
	// if selectedDOMRange contains dragCaretDOMRange, change href of selection
	if ( (startToStart == -1) && (endToEnd == 1) ) // this appears to be the correct answer via testing
	{
		[self insertHref:URLAsString inRange:selectedDOMRange];
		// maybe change this if a link were already there?
		[[[[self webViewController] webView] undoManager] setActionName:NSLocalizedString(@"Insert Link","Action Name: Insert Link")];
		return YES;
	}
	
	// otherwise, insert a new text node at caretPosition
	else
	{
		long caretPosition = [dragCaretDOMRange startOffset];
		[self insertText:title href:URLAsString inRange:dragCaretDOMRange atPosition:caretPosition];
		[[[[self webViewController] webView] undoManager] setActionName:NSLocalizedString(@"Insert Link","Action Name: Insert Link")];
		return YES;
	}
	
	// shouldn't get here
	return NO;
}

// these methods share a bunch of code with the link panel link creation and should be refactored

- (void)insertHref:(NSString *)aURLAsString inRange:(DOMRange *)aRange
{
	OFF((@"insertHref:%@ inRange:%@", aURLAsString, aRange));
	DOMNode *startNode = [aRange startContainer];
	DOMNode *endNode = [aRange endContainer];
	DOMNode *parentNode = [startNode parentNode];
	
	if ( [startNode isKindOfClass:[DOMText class]] )
	{
		// turn the selection into a new text node
		DOMText *text = [[startNode ownerDocument] createTextNode:[aRange toString]];
		
		// fire up a new anchor with text
		DOMHTMLAnchorElement *anchor = (DOMHTMLAnchorElement *)[[startNode ownerDocument] createElement:@"a"];
		[anchor setHref:aURLAsString];
		[anchor appendChild:text];				
		
		// chop the selection out of the range, alters both startNode and endNode
		(void)[aRange extractContents];
		
		// insert anchor
		if ( [startNode isEqual:endNode] )
		{
			// split the remainder at the start
			DOMNode *split = [(DOMText *)startNode splitText:[aRange startOffset]];
			
			// add the new anchor before the split
			[[DOMNode class] node:parentNode insertBefore:anchor :split];
		}
		else
		{
			// add anchor after startNode
			DOMNode *nextSibling = [startNode nextSibling];
			if ( nil != nextSibling )
			{
				[[DOMNode class] node:parentNode insertBefore:anchor :nextSibling];
			}
			else
			{
				[[DOMNode class] node:parentNode appendChild:anchor];
			}
		}
	}	
	else
	{
		NSBeep();
		NSLog(@"insertHref:inRange: DOMRange does not contain a useable DOMText!");
	}
	
}

- (void)insertText:(NSString *)aTextString href:(NSString *)aURLAsString inRange:(DOMRange *)aRange atPosition:(long)aPosition
{
	OFF((@"insertText:%@ href:%@ inRange:%@ atPosition:%l", aTextString, aURLAsString, aRange, aPosition));
	// make sure we're looking at a useable node
	DOMNode *startNode = [aRange startContainer];
	if ( [startNode respondsToSelector:@selector(splitText:)] )
	{
		// turn aTextString into a new text node
		DOMText *text = [[startNode ownerDocument] createTextNode:aTextString];
		
		// fire up a new anchor with text
		DOMHTMLAnchorElement *anchor = (DOMHTMLAnchorElement *)[[startNode ownerDocument] createElement:@"a"];
		[anchor setHref:aURLAsString];
		[anchor appendChild:text];
		
		// split the DOM at aPosition
		DOMNode *split = [(DOMText *)startNode splitText:aPosition];
		
		// add the new anchor before the split
		[[DOMNode class] node:[startNode parentNode] insertBefore:anchor :split];
	}
	else
	{
		NSBeep();
		OFF((@"insertText:href:inRange:atPosition: DOMRange does not respond to splitText:!"));
	}
}

@end

