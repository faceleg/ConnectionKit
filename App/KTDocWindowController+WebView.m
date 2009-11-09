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
#import "KTSite.h"
#import "KTElementPlugin.h"
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


NSString *KTSelectedDOMRangeKey = @"KTSelectedDOMRange";


@interface KTDocWebViewController (EditingPrivate)
- (void)setCurrentTextEditingBlock:(SVHTMLTextBlock *)textBlock;
@end


@interface KTDocWindowController ( WebViewPrivate )

- (NSPoint)linkPanelTopLeftPointForSelectionRect:(NSRect)aSelectionRect;
- (DOMHTMLElement *)elementOfClass:(NSString *)aDesiredClass enclosing:(DOMNode *)aNode;

- (NSString *)createLink:(NSString *)link openLinkInNewWindow:(BOOL)openLinkInNewWindow;
- (NSString *)removeLinkWithDOMRange:(DOMRange *)selectedRange;

- (void)insertHref:(NSString *)aURLAsString inRange:(DOMRange *)aRange;
- (void)insertText:(NSString *)aTextString href:(NSString *)aURLAsString inRange:(DOMRange *)aRange atPosition:(long)aPosition;

@end


#pragma mark -


@implementation KTDocWindowController (WebView)

#pragma mark -
#pragma mark Image Replacement

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
		return [[[self document] site] root];	// don't need to look up object; it's the root
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
			NSArray *fetchedObjects = [context objectsWithEntityName:@"OldPagelet"
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
	return [[self document] site];
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
	NSDictionary *info = [self contextElementInformation];
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
	NSDictionary *info = [[self contextElementInformation] retain];
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
            [[[self webViewController] webView] setSelectedDOMRange:selectedRange affinity:NSSelectionAffinityDownstream];
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
 */
- (NSString *)createLink:(NSString *)link openLinkInNewWindow:(BOOL)openLinkInNewWindow
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
		[anchor appendChild:[selectedRange cloneContents]];
		
		
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
			undoActionName = [self createLink:[info valueForKey:@"KTLocalLink"] openLinkInNewWindow:[oLinkOpenInNewWindowSwitch state] == NSOnState];
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
				undoActionName = [self createLink:value openLinkInNewWindow:[oLinkOpenInNewWindowSwitch state] == NSOnState];
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

#pragma mark -
#pragma mark TextField Delegate

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
	//LOG((@"controlTextDidEndEditing: %@", aNotification));
	id object = [aNotification object];
	if ( [object isEqual:oLinkDestinationField] )
	{
		/// defend against nil
		NSString *string = [[[object stringValue] stringWithValidURLScheme] stringByTrimmingFirstLine];
		if (nil == string) string = @"";
		[object setStringValue:string];
	}
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	//LOG((@"controlTextDidEndEditing: %@", aNotification));
	id object = [aNotification object];
	if ( [object isEqual:oLinkDestinationField] )
	{
		NSString *value = [[[oLinkDestinationField stringValue] stringWithValidURLScheme] stringByTrimmingFirstLine];
		
		BOOL empty = ( [value isEqualToString:@""] 
                      || [value isEqualToString:@"http://"] 
                      || [value isEqualToString:@"https://"] 
                      || [value isEqualToString:@"ftp://"]
                      || [value isEqualToString:@"mailto:"] );
		
		[oLinkView setConnected:!empty];
	}
}


- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor;
{
	if ( [control isEqual:oLinkDestinationField] )
	{
		NSString *value = [[[oLinkDestinationField stringValue] stringWithValidURLScheme] stringByTrimmingFirstLine];
		
		if ( [value isEqualToString:@""] 
            || [value isEqualToString:@"http://"] 
            || [value isEqualToString:@"https://"] 
            || [value isEqualToString:@"ftp://"]
            || [value isEqualToString:@"mailto:"] )
		{
			// empty, this is OK
			return YES;
		}
		else if ( [value hasPrefix:@"mailto:"] )
		{
			// check how mailto looks.
			if ( NSNotFound == [value rangeOfString:@"@"].location )
			{
				return NO;
			}
		}
		else
		{
			// Check how URL looks.  If it's bad, beep and exit -- don't let them close.
			NSURL *checkURL = [NSURL URLWithUnescapedString:value];
            
			NSString *host = [checkURL host];
			NSString *path = [checkURL path];
			if (NULL == checkURL
				|| (NULL == host && NULL == path) 
				|| (NULL != host && NSNotFound == [host rangeOfString:@"."].location) )
			{
				return NO;
			}
		}
	}
	return YES;
}

@end

