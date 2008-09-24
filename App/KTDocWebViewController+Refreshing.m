//
//  KTDocWebViewController+Refreshing.m
//  Marvel
//
//  Created by Mike on 16/09/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//
//
//	This portion of the webview controller handles the loading and updating of content inside the webview.
//	To load a page, we ask it for its content HTML and insert that into the webview. All fairly straightforward.
//	However, while building the HTML, the webview controller builds a hierarchy in its memory of the various components
//	and their keypaths that make up the page. The controller can then observer these objects to know when and what to update
//	in the webview.


#import "KTDocWebViewController.h"
#import "KTDocWebViewController+Private.h"

#import "Debug.h"
#import "KTAbstractIndex.h"
#import "KTDocWindowController.h"
#import "KTHTMLParser.h"
#import "KTPage.h"
#import "KTWebViewComponent.h"
#import "KTAsyncOffscreenWebViewController.h"
#import "KTHTMLTextBlock.h"
#import "WebViewEditingHelperClasses.h"

#import "NSMutableDictionary+Karelia.h"
#import "NSString-Utilities.h"
#import "NSTextView+KTExtensions.h"
#import "NSThread+Karelia.h"

#import "DOMNode+KTExtensions.h"


@interface DOMHTMLDocument ( TenFourElevenAndAboveWebkit )
- (DOMDocumentFragment *)createDocumentFragmentWithMarkupString:(NSString *)markupString baseURL:(NSURL *)baseURL;
- (DOMDocumentFragment *)createDocumentFragmentWithText:(NSString *)text;
@end

@interface KTDocWebViewController (RefreshingPrivate)

- (void)_setWebViewNeedsReload:(BOOL)needsRefresh;
- (void)_setWebViewComponentNeedsReload:(KTWebViewComponent *)component;

- (void)reloadWebViewComponent:(KTWebViewComponent *)component;

- (void)loadPageIntoWebView:(KTPage *)page;

- (KTWebViewComponent *)webViewComponentForParser:(KTHTMLParser *)parser;
- (void)resetWebViewComponent:(KTWebViewComponent *)component;

- (void)addParsedKeyPath:(NSString *)keyPath ofObject:(NSObject *)object forParsedComponent:(KTWebViewComponent *)parsedComponent;

- (void)loadMultiplePagesMarkerIntoWebView;

// Source Code text view loading
- (void)loadPageIntoSourceCodeTextView:(KTPage *)page;
- (void)loadSourceCodeIntoSourceCodeTextView:(NSString *)sourceCode;

@end


#pragma mark -


@implementation KTDocWebViewController (Refreshing)

#pragma mark -
#pragma mark Initialization & Deallocation

- (void)init_webViewLoading
{
}

- (void)dealloc_webViewLoading
{
	[[self webView] stopLoading:nil];
	[[self asyncOffscreenWebViewController] stopLoading];
	[self _setWebViewNeedsReload:NO];
    
    [self setPages:nil];
}

#pragma mark -
#pragma mark Pages

- (NSSet *)pages { return myPages; }

- (void)setPages:(NSSet *)pages
{
    // Stop observation if needed
    KTPage *oldPage = [self page];
    if (oldPage)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:NSManagedObjectContextObjectsDidChangeNotification
                                                      object:[oldPage managedObjectContext]];
    }
    
    
    // Store pages
    pages = [pages copy];
    [myPages release];
    myPages = pages;
    
    
    // Reload
    [self reloadWebView];
    
    
    // Observe new page if needed
    KTPage *page = [self page];
    if (page)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(managedObjectContextObjectsDidChange:)
                                                     name:NSManagedObjectContextObjectsDidChangeNotification
                                                   object:[page managedObjectContext]];
    }
}

- (KTPage *)page
{
    NSSet *pages = [self pages];
    KTPage *result = ([pages count] == 1) ? [pages anyObject] : nil;
    return result;
}

#pragma mark -
#pragma mark Needs Reload

- (BOOL)webViewNeedsReload
{
	return (myRunLoopObserver != nil);
}


/*	Convenience (and public) method for marking the entire webview for a reload.
 */
- (void)setWebViewNeedsReload
{
	[self _setWebViewComponentNeedsReload:[self mainWebViewComponent]];
}


/*	Private method for marking an individual component as needing a refresh.
 *	DO NOT use -[KTParsedWebViewComponent setNeedsReload:] instead as it will not be detected by the webview controller.
 *
 *	If component is nil, we assume the whole webview needs a refresh
 */
- (void)_setWebViewComponentNeedsReload:(KTWebViewComponent *)component
{
	// Mark the component
	if (!component) component = [self mainWebViewComponent];
	
	[component setNeedsReload:YES];
	[self resetWebViewComponent:component];
	
	
	// Schedule the actual reload
	[self _setWebViewNeedsReload:YES];
}


/*	Private callback function for scheduled webview loading
 */
void ReloadWebViewIfNeeded(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info)
{
	KTDocWebViewController *webViewController = info;
	[webViewController reloadWebViewIfNeeded];
}

/*	Private method. Called whenever some portion of the webview needs reloading.
 *	Schedules a CFRunLoopObserver to perform the actual reload at the end of the run loop.
 */
- (void)_setWebViewNeedsReload:(BOOL)needsRefresh
{ 
	if (needsRefresh && !myRunLoopObserver)
	{
		// Install a fresh observer for the end of the run loop
		CFRunLoopObserverContext context = { 0, self, NULL, NULL, NULL };
		myRunLoopObserver = CFRunLoopObserverCreate(NULL, kCFRunLoopExit, NO, 0, &ReloadWebViewIfNeeded, &context);
		CFRunLoopAddObserver([[NSRunLoop currentRunLoop] getCFRunLoop], myRunLoopObserver, kCFRunLoopCommonModes);
	}
	else if (!needsRefresh && myRunLoopObserver)
	{
		// Unschedule the existing observer and throw it away
		CFRunLoopRemoveObserver([[NSRunLoop currentRunLoop] getCFRunLoop], myRunLoopObserver, kCFRunLoopCommonModes);
		CFRelease(myRunLoopObserver);	myRunLoopObserver = NULL;
	}
}

- (void)managedObjectContextObjectsDidChange:(NSNotification *)notification
{
    [self setWebViewNeedsReload];
}

#pragma mark -
#pragma mark Loading

- (void)reloadWebView
{
	// The notification to do this doesn't get called, so we have to manually set it before reloading
	[self setCurrentTextEditingBlock:nil];
    [[[self webView] undoManager] performSelector:@selector(removeAllWebViewTargettedActions)];
	
	
	// Throw away the old component tree
	[self setMainWebViewComponent:nil];
	
	
	// How we load depends on the current selection
	NSSet *selectedPages = [self pages];
	if (!selectedPages || [selectedPages count] == 0)
	{
		[[[self webView] mainFrame] loadHTMLString:@"" baseURL:nil];
	}
	else if ([selectedPages count] == 1)
	{
		[[WebPreferences standardPreferences] setJavaScriptEnabled:YES];	// enable javascript to force + button to work
		[[self webView] setPreferences:[WebPreferences standardPreferences]];	// force it to load new prefs
		
		KTPage *selectedPage = [selectedPages anyObject];
        [self loadPageIntoWebView:selectedPage];
		
		
		// Also load the source code text view if it's visible
		if ([self hideWebView])
		{
			[self loadPageIntoSourceCodeTextView:selectedPage];
		}
	}
	else
	{
		[self loadMultiplePagesMarkerIntoWebView];
	}
	
	
	// Clear out status field, need to move over something to get it populated
	[[self windowController] setStatusField:@""];
	
	
	// Clearly the webview is no longer in need of refreshing
	[self _setWebViewNeedsReload:NO];
}


/*	Generates HTML for just the specified component and inserts it into the webview, replacing the old HTML
 */
- (void)reloadWebViewComponent:(KTWebViewComponent *)component
{
	// If we're trying to redraw the main component, cut straight to -refreshWebView
	if ([component isEqual:[self mainWebViewComponent]])
	{
		[self reloadWebView];
		return;
	}
	
	
	// Search for the div with the right ID.
	NSString *divID = [component divID];
	DOMHTMLDocument *document = (DOMHTMLDocument *)[[[self webView] mainFrame] DOMDocument];
	OBASSERT([document isKindOfClass:[DOMHTMLDocument class]]);
	DOMHTMLElement *element = (DOMHTMLElement *)[document getElementById:divID];
	
	// If a suitable element couldn't be found try the component's parent instead
	if (!element || ![element isKindOfClass:[DOMHTMLDivElement class]])
	{
		[self reloadWebViewComponent:[component supercomponent]];
		return;
	}
	
	
	id parsedComponent = [[component parser] component];
	NSString *templateHTML = [[component parser] template];
	
	
	// Mark the component as no longer needing a refresh
	[component setNeedsReload:NO];
	
	
	// Before generating the HTML, we need to change the key of the component to reflect the new parser that's going to be used
	KTHTMLParser *parser = [[KTHTMLParser alloc] initWithTemplate:templateHTML component:parsedComponent];
	[parser setHTMLGenerationPurpose:kGeneratingPreview];
	
	[component retain];
	[component release];
	
	
	// Generate the HTML that will replace the component
	[parser setDelegate:self];
	KTPage *page = [self page];
	[parser setCurrentPage:page];
	if ([parsedComponent isKindOfClass:[KTAbstractIndex class]])	// A hack to handle indexes in 1.5
	{
		[parser overrideKey:@"pages" withValue:[page pagesInIndex]];
	}
	
	NSString *replacementHTML = [parser parseTemplate];
	[parser release];


/*
 // Take out the old (now, so we see the change?)
 
 if ([element hasChildNodes])
	{
		DOMNodeList *childNodes = [element childNodes];
		int i, length = [childNodes length];
		// Move to parent
		for (i = 0 ; i < length ; i++)
		{
			DOMNode *child = [childNodes item:0];	// removing, so always get item 0
			[element removeChild:child];
		}
	}
*/	
	// We ought to be able to turn off javascript instead but that doesn't work.
	// <rdar://problem/5898308> setJavaScriptEnabled:NO doesn't immediately disable JavaScript execution

	[[self asyncOffscreenWebViewController] setDelegate:self];
	[self setElementWaitingForFragmentLoad:element];
	// Kick off load of fragment, we will be notified when it's done.
	[[self asyncOffscreenWebViewController]  loadHTMLFragment:replacementHTML];

	
	// Reload the source code text view if it's visible
	if ([self hideWebView])
	{
		[self loadPageIntoSourceCodeTextView:page];
	}
}


/*	This splices the DOM tree that has been loaded into the offscreen webview into the element
 *	that is waiting for this fragment to have finished loading, [self elementWaitingForFragmentLoad].
 *	First it removes any existing children of that element (since we are replacing it),
 *	Then it imports the loaded body into the destination webview's DOMDocument (via importNode::)
 *	Finally, it loops through each element and find all the <script> elements, and, in order to
 *	prevent any script tags from executing (again, since they would have executed in the offscreen
 *	view), it strips out the info that will allow the script to execute.  This unfortunately affects
 *	the DOM for view source, but this isn't stored in the permanent database since this is just
 *	surgery on the currently viewed webview.
 * 
 *	Finally, after processing, we insert the new tree into the webview's tree, and process editing
 *	nodes to bring us the green + markers.
 */
- (void)spliceElement:(DOMHTMLElement *)loadedBody;
{
	DOMHTMLElement *element = [self elementWaitingForFragmentLoad];
	if ([element hasChildNodes])
	{
		DOMNodeList *childNodes = [element childNodes];
		int i, length = [childNodes length];
		// Move to parent
		for (i = 0 ; i < length ; i++)
		{
			DOMNode *child = [childNodes item:0];	// removing, so always get item 0
			[element removeChild:child];
		}
	}

	DOMHTMLDocument *document = (DOMHTMLDocument *)[[[self webView] mainFrame] DOMDocument];
	DOMNode *imported = [document importNode:loadedBody :YES];
	
	// I have to turn off the script nodes from actually executing
	DOMNodeIterator *it = [document createNodeIterator:imported :DOM_SHOW_ELEMENT :[ScriptNodeFilter sharedFilter] :NO];
	DOMHTMLScriptElement *subNode;
		
	while ((subNode = (DOMHTMLScriptElement *)[it nextNode]))
	{
		[subNode setText:@""];		/// HACKS -- clear out the <script> tags so that scripts are not executed AGAIN
		[subNode setSrc:@""];
		[subNode setType:@""];
	}
	
	[element appendChildren:[imported childNodes]];
	[self processEditableElementsFromElement:element];

}


/*	This is the most important part of webview management.
 *	Generates fresh HTML for the page and compares it to the existing to refresh the affected components.
 *	Calling -setWebViewNeedsReload will schedule this method at the end of the runloop.
 */
- (void)reloadWebViewIfNeeded;
{
	if (![self webViewNeedsReload]) return;
	
	
	// Generate a fresh component tree
	KTHTMLParser *parser = [[KTHTMLParser alloc] initWithPage:[self page]];
	
	KTWebViewComponent *webViewComponent = [[KTWebViewComponent alloc] initWithParser:parser];
	[parser setDelegate:webViewComponent];
	
	[parser setHTMLGenerationPurpose:kGeneratingPreview];
	[parser setIncludeStyling:([self viewType] != KTWithoutStylesView)];
	
	[parser parseTemplate];
	[parser release];
	
	
	// Look for components which don't match
	//[[webViewComponent outerHTML] isEqualToString:[[self mainWebViewComponent] outerHTML]];
	
	
	
	// Tidy up
	[webViewComponent release];
	
	[self _setWebViewNeedsReload:NO];
}

#pragma mark -
#pragma mark WebView Loading

- (void)loadPageIntoWebView:(KTPage *)page
{
	// Build the HTML
	KTHTMLParser *parser = [[KTHTMLParser alloc] initWithPage:page];
	
	KTWebViewComponent *webViewComponent = [[KTWebViewComponent alloc] initWithParser:parser];
	[self setMainWebViewComponent:webViewComponent];
	[parser setDelegate:webViewComponent];
	[webViewComponent release];
	
	[parser setHTMLGenerationPurpose:kGeneratingPreview];
	[parser setIncludeStyling:([self viewType] != KTWithoutStylesView)];
	
	NSString *pageHTML = [parser parseTemplate];
	[parser release];
	
	// Load the HTML into the webview
	[[[self webView] mainFrame] loadHTMLString:pageHTML baseURL:nil];
}

- (void)loadMultiplePagesMarkerIntoWebView
{
	// put up the multiple selection page
	NSString *pagePath = [[NSBundle mainBundle] pathForResource:@"MultipleSelection" ofType:@"html"];
	NSURL *pageURL = [NSURL fileURLWithPath:pagePath];
	NSURLRequest *request = [NSURLRequest requestWithURL:pageURL];
	[[[self webView] mainFrame] loadRequest:request];
}

#pragma mark -
#pragma mark Source Code Text View Loading

/*	This section of code is responsible for loading a page's HTML source into the source code text view.
 *	We rely on higher level code (namely -refreshWebView et al.) to call us when appropriate.
 */

- (void)loadPageIntoSourceCodeTextView:(KTPage *)page
{
	// Figure out the right source code dependent on current view type
	NSString *sourceCode = nil;
	switch ([self viewType])
	{
		case KTSourceCodeView:
			sourceCode = [page contentHTMLWithParserDelegate:nil isPreview:NO];
			break;
		
		case KTDOMSourceView:
		{
			DOMDocument *document = [[[self webView] mainFrame] DOMDocument];
			NSString *dtd = [page DTD];
			DOMNode *child = [document firstChild];
			NSString *html = @"";
			if (![child isKindOfClass:[DOMHTMLElement class]])
			{
				child = [[document childNodes] item:1];
			}
			if ([child isKindOfClass:[DOMHTMLElement class]])
			{
				html = [child cleanedOuterHTML];
			}
			sourceCode = [NSString stringWithFormat:@"%@\n%@", dtd, html];
			break;
		}
		
		case KTRSSSourceView:
			sourceCode = [page RSSFeedWithParserDelegate:nil];
			break;
		
		default:
			OBASSERT_NOT_REACHED("Attempting to an unsported view type into the source code textview.");
			break;
	}
	
	// Load the code
	if (sourceCode)
	{
		[self loadSourceCodeIntoSourceCodeTextView:sourceCode];
	}
}

- (void)loadSourceCodeIntoSourceCodeTextView:(NSString *)sourceCode
{
	// Scroll the text view back to the very top
	NSTextView *textView = [self sourceCodeTextView];
	[textView scrollPoint:NSZeroPoint];
	
	// Load in the text
	NSMutableAttributedString *textStorage = [textView textStorage];
	[textStorage replaceCharactersInRange:NSMakeRange(0, [textStorage length]) withString:sourceCode];
	
	// Apply syntax highlighting
	[textView recolorRange:NSMakeRange(0, [sourceCode length])];
}

#pragma mark -
#pragma mark WebView Components

- (KTWebViewComponent *)mainWebViewComponent { return myMainWebViewComponent; }

- (void)setMainWebViewComponent:(KTWebViewComponent *)component
{
	// Do the usual behavior for dumping a component. This empties the component out, including subcomponents, but keeps
	// the component itself in the tree...
	[self resetWebViewComponent:[self mainWebViewComponent]];
	[[self mainWebViewComponent] setWebViewController:nil];
		
	[component retain];
	[myMainWebViewComponent release];
	myMainWebViewComponent = component;
	
	[component setWebViewController:self];
}

/*	Leaves the actual component in the hierarchy, but removes all its subComponents & parsed keyPaths.
 *	Before doing so, we stop all KVO for the objects contained.
 */
- (void)resetWebViewComponent:(KTWebViewComponent *)component
{
	// Deal with subcomponents first
	NSArray *subcomponents = [component subcomponents];
	NSEnumerator *subcomponentsEnumerator = [subcomponents objectEnumerator];
	KTWebViewComponent *aSubcomponent;
	while (aSubcomponent = [subcomponentsEnumerator nextObject])
	{
		[self resetWebViewComponent:aSubcomponent];
	}
	
	[component removeAllSubcomponents];
}

#pragma mark -
#pragma mark Page Key Paths

/*	We are registered to know when the document will close so that key paths can be cleared out first.
 *	Otherwise, one key path is bound to try to access the document and then ... kaboom!
 */
- (void)documentWillClose:(NSNotification *)notification
{
	[self setMainWebViewComponent:nil];
	[self _setWebViewNeedsReload:NO];
}

@end
