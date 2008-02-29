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
#import "KTDocSiteOutlineController.h"
#import "KTDocWindowController.h"
#import "KTHTMLParser.h"
#import "KTPage.h"
#import "KTParsedKeyPath.h"
#import "KTParsedWebViewComponent.h"
#import "NSString-Utilities.h"
#import "NSTextView+KTApplication.h"
#import "NSThread+Karelia.h"

#import "DOMNode+KTExtensions.h"


@interface KTDocWebViewController (RefreshingPrivate)

- (NSSet *)webViewComponentsNeedingRefresh;

- (void)_refreshWebView;
- (void)loadPageIntoWebView:(KTPage *)page;

- (KTParsedWebViewComponent *)webViewComponentForParser:(KTHTMLParser *)parser;
- (void)resetWebViewComponent:(KTParsedWebViewComponent *)component;

- (void)addParsedKeyPath:(NSString *)keyPath ofObject:(NSObject *)object forParsedComponent:(KTParsedWebViewComponent *)parsedComponent;
- (NSSet *)webViewComponentsWithParsedKeyPath:(KTParsedKeyPath *)keyPath;

- (void)loadMultiplePagesMarkerIntoWebView;

// Source Code text view loading
- (void)loadPageIntoSourceCodeTextView:(KTPage *)page;
- (void)loadSourceCodeIntoSourceCodeTextView:(NSString *)sourceCode;

@end


#pragma mark -


@implementation KTDocWebViewController (Refreshing)

#pragma mark -
#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	KTParsedKeyPath *parsedKeyPath = [[[KTParsedKeyPath alloc] initWithKeyPath:keyPath ofObject:object] autorelease];
	
	
	// If refreshing for this particular key path & object has been suspended then perform refreshing later
	if ([mySuspendedKeyPaths containsObject:parsedKeyPath])
	{
		[mySuspendedKeyPathsAwaitingRefresh addObject:parsedKeyPath];
	}
	else
	{
		// Gather up all the components that rely on this keypath and mark them as needing refreshing
		NSSet *componentsToRefresh = [self webViewComponentsWithParsedKeyPath:parsedKeyPath];
		NSEnumerator *componentsEnumerator = [componentsToRefresh objectEnumerator];
		KTParsedWebViewComponent *aComponent;
		while (aComponent = [componentsEnumerator nextObject])
		{
			[self setWebViewComponentNeedsRefresh:aComponent];
		}
	}
}

#pragma mark -
#pragma mark Public Refresh API

/*	The web view needs refreshing if any of our components do
 */
- (BOOL)webViewNeedsRefresh
{
	BOOL result = (myWholeWebViewNeedsRefresh || [[self webViewComponentsNeedingRefresh] count] > 0);
	return result;
}

/*	Sets the main web view component as needing a refresh or clears out the list of components needing refreshing.
 */
- (void)setWebViewNeedsRefresh:(BOOL)needsRefresh
{
	if (needsRefresh)
	{
		[self setWebViewComponentNeedsRefresh:nil];
	}
	else
	{
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshWebViewIfNeeded) object:nil];
		[myComponentsNeedingRefresh removeAllObjects];
		myWholeWebViewNeedsRefresh = NO;
	}
}

/*	If component is nil or our main component, then assume the whole webview needs a refresh
 */
- (void)setWebViewComponentNeedsRefresh:(KTParsedWebViewComponent *)component
{
	// If the whole page needs refreshing don't bother with any fiddly stuff!
	if (!component || myWholeWebViewNeedsRefresh || [component isEqual:[self mainWebViewComponent]])
	{
		myWholeWebViewNeedsRefresh = YES;
	}
	else
	{
		// There is no point refreshing a component AND its parent. So ensure we have the most efficient set of objects listed.
		BOOL aSuperComponentAlreadyNeedsRefreshing = [myComponentsNeedingRefresh intersectsSet:[component allSuperComponents]];
		if (!aSuperComponentAlreadyNeedsRefreshing)
		{
			[myComponentsNeedingRefresh addObject:component];
			[myComponentsNeedingRefresh minusSet:[component allSubComponents]];
		}
	}
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshWebViewIfNeeded) object:nil];
	[self performSelector:@selector(refreshWebViewIfNeeded) withObject:nil afterDelay:0.0];
}

- (NSSet *)webViewComponentsNeedingRefresh
{
	return [NSSet setWithSet:myComponentsNeedingRefresh];
}

- (void)refreshWebView
{
	[self _refreshWebView];	// Does the real work
	
	[[self windowController] setStatusField:@""];		// clear out status field, need to move over something to get it populated
	
	[self setWebViewNeedsRefresh:NO];
}

- (void)_refreshWebView
{
	[self setMainWebViewComponent:nil];
	
	NSSet *selectedPages = [[[self windowController] siteOutlineController] selectedPages];
	
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
}

- (void)refreshWebViewComponent:(KTParsedWebViewComponent *)component
{
	// If we're trying to redraw the main component cut straight to -refreshWebView
	if ([component isEqual:[self mainWebViewComponent]])
	{
		[self refreshWebView];
		return;
	}
	
	
	// Search for the div with the right ID.
	NSString *divID = [component divID];
	DOMDocument *document = [[[self webView] mainFrame] DOMDocument];
	DOMElement *element = [document getElementById:divID];
	
	// If a suitable element couldn't be found try the component's parent instead
	if (!element || ![element isKindOfClass:[DOMHTMLDivElement class]])
	{
		[self refreshWebViewComponent:[component superComponent]];
		return;
	}
	
	
	id parsedComponent = [component parsedComponent];
	NSString *templateHTML = [component templateHTML];
	
	// Mark all the component + subcomponents as no longer needing a refresh
	[myComponentsNeedingRefresh minusSet:[component allSubComponents]];
	[myComponentsNeedingRefresh removeObject:component];
	
	// Remove the old component from our hierarchy. This has the effect of killing all subComponents plus any KVO.
	[self resetWebViewComponent:component];
	
	// Before generating the HTML, we need to change the key of the component to reflect the new parser that's going to be used
	KTHTMLParser *parser = [[KTHTMLParser alloc] initWithTemplate:templateHTML component:parsedComponent];
	[parser setHTMLGenerationPurpose:kGeneratingPreview];
	
	[component retain];
	[myWebViewComponents removeObjectsForKeys:[myWebViewComponents allKeysForObject:component]];
	[myWebViewComponents setObject:component forKey:[parser parserID]];
	[component release];
	
	
	// Generate the HTML that will replace the component
	[parser setDelegate:self];
	KTPage *page = (KTPage *)[[self mainWebViewComponent] parsedComponent];
	[parser setCurrentPage:page];
	NSString *replacementHTML = [parser parseTemplate];
	[parser release];
	
	
	// Replace HTML in the DOM and reprocess editable elements
	[(DOMHTMLElement *)element setInnerHTML:replacementHTML];
	[self processEditableElementsFromDoc:[element ownerDocument]];
	
	
	// Reload the source code text view if it's visible
	if ([self hideWebView])
	{
		[self loadPageIntoSourceCodeTextView:page];
	}
}

- (void)refreshWebViewIfNeeded;
{
	OBASSERT([NSThread isMainThread]);	// This method should only happen on the main thread.
										// This is a temporary to test to see if this is the case.
	
	// Refresh those parts of the webview that need it
	if (myWholeWebViewNeedsRefresh)
	{
		[self refreshWebView];
	}
	else
	{
		NSEnumerator *componentsEnumerator = [[self webViewComponentsNeedingRefresh] objectEnumerator];
		KTParsedWebViewComponent *aComponent;
		while (aComponent = [componentsEnumerator nextObject])
		{
			[self refreshWebViewComponent:aComponent];
		}
	}
	
	LOG((@"Refreshed Webview"));
}

#pragma mark -
#pragma mark Suspended Refreshes

- (void)suspendWebViewRefreshingForKeyPath:(NSString *)keyPath ofObject:(id)anObject
{
	KTParsedKeyPath *keyPathObject = [[KTParsedKeyPath alloc] initWithKeyPath:keyPath ofObject:anObject];
	[mySuspendedKeyPaths addObject:keyPathObject];
	[keyPathObject release];
}

- (void)resumeWebViewRefreshingForKeyPath:(KTParsedKeyPath *)keyPath
{
	[mySuspendedKeyPaths removeObject:keyPath];
	
	// If that key path has been awaiting refresh, go ahead an do so.
	if (![mySuspendedKeyPaths containsObject:keyPath] &&
		[mySuspendedKeyPathsAwaitingRefresh containsObject:keyPath])
	{
		[self observeValueForKeyPath:[keyPath keyPath] ofObject:[keyPath parsedObject] change:nil context:NULL];
		[mySuspendedKeyPathsAwaitingRefresh removeObject:keyPath];
	}
}

- (void)resumeWebViewRefreshingForKeyPath:(NSString *)keyPath ofObject:(id)anObject
{
	KTParsedKeyPath *keyPathObject = [[KTParsedKeyPath alloc] initWithKeyPath:keyPath ofObject:anObject];
	[self resumeWebViewRefreshingForKeyPath:keyPathObject];
	[keyPathObject release];
}

- (void)resumeWebViewRefreshing
{
	NSSet *suspendedKeyPaths = [NSSet setWithSet:mySuspendedKeyPaths];
	[mySuspendedKeyPaths removeAllObjects];
	
	NSEnumerator *suspendedKeyPathsEnumerator = [suspendedKeyPaths objectEnumerator];
	KTParsedKeyPath *aKeyPath;
	while (aKeyPath = [suspendedKeyPathsEnumerator nextObject])
	{
		[self resumeWebViewRefreshingForKeyPath:aKeyPath];
	}
}

#pragma mark -
#pragma mark WebView Loading

- (void)loadPageIntoWebView:(KTPage *)page
{
	// Build the HTML
	NSString *pageHTML = [page contentHTMLWithParserDelegate:self isPreview:YES];
	
	// There's a few keypaths that the parser will not pick up. We have to explicitly observe them here.
	[self addParsedKeyPath:@"pluginHTMLIsFullPage" ofObject:page forParsedComponent:[self mainWebViewComponent]];
	[self addParsedKeyPath:@"master.bannerImage.file" ofObject:page forParsedComponent:[self mainWebViewComponent]];
	
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

- (void)HTMLParser:(KTHTMLParser *)parser didEncounterKeyPath:(NSString *)keyPath ofObject:(id)object
{
	[self addParsedKeyPath:keyPath ofObject:object forParser:parser];
}

- (void)HTMLParser:(KTHTMLParser *)parser didParseTextBlock:(KTWebViewTextEditingBlock *)textBlock
{
	KTParsedWebViewComponent *component = [self webViewComponentForParser:parser];
	[component addTextBlock:textBlock];
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
			NSString *html = [[document firstChild] cleanedOuterHTML];
			sourceCode = [NSString stringWithFormat:@"%@\n%@", dtd, html];
			break;
		}
		
		case KTRSSSourceView:
			sourceCode = [page RSSRepresentation];
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

- (KTParsedWebViewComponent *)mainWebViewComponent { return myMainWebViewComponent; }

- (void)setMainWebViewComponent:(KTParsedWebViewComponent *)component
{
	// Stop observing every key path of the old component (and subComponents)
	NSAutoreleasePool *tempPool = [[NSAutoreleasePool alloc] init];		// Lots of enumerating here so make a local pool
	
	NSEnumerator *componentsEnumerator = [myWebViewComponents objectEnumerator];
	KTParsedWebViewComponent *aComponent;
	
	while (aComponent = [componentsEnumerator nextObject])
	{
		NSEnumerator *keyPathsEnumerator = [[aComponent parsedKeyPaths] objectEnumerator];
		KTParsedKeyPath *aKeyPath;
		while (aKeyPath = [keyPathsEnumerator nextObject])
		{
			[[aKeyPath parsedObject] removeObserver:self forKeyPath:[aKeyPath keyPath]];
		}
	}
	
	[tempPool release];	// Tidy up
	[myWebViewComponents removeAllObjects];
	
	// Standard accessor
	[component retain];
	[myMainWebViewComponent release];
	myMainWebViewComponent = component;
}

/*	Locates the component that corresponds with the parser. If none is found, creates it.
 */
- (KTParsedWebViewComponent *)webViewComponentForParser:(KTHTMLParser *)parser
{
	// Ensure we have a main parsed component before doing anything else
	if (![self mainWebViewComponent])
	{
		KTParsedWebViewComponent *mainComponent = [[KTParsedWebViewComponent alloc] initWithParser:parser];
		[self setMainWebViewComponent:mainComponent];
		[myWebViewComponents setObject:mainComponent forKey:[parser parserID]];
		[mainComponent release];
	}
	
	
	// Search for the component
	KTParsedWebViewComponent *result = [myWebViewComponents objectForKey:[parser parserID]];
	
	
	// Create a new component if not found
	if (!result)
	{
		KTParsedWebViewComponent *parentComponent = [self webViewComponentForParser:[parser parentParser]];
		
		result = [[KTParsedWebViewComponent alloc] initWithParser:parser];
		[parentComponent addSubComponent:result];
		[myWebViewComponents setObject:result forKey:[parser parserID]];
		[result release];
	}
	
	return result;
}

/*	Leaves the actual component in the hierarchy, but removes all its subComponents & parsed keyPaths.
 *	Before doing so, we stop all KVO for the objects contained.
 */
- (void)resetWebViewComponent:(KTParsedWebViewComponent *)component
{
	// Stop observing keypaths of the component
	NSEnumerator *keyPathsEnumerator = [[component parsedKeyPaths] objectEnumerator];
	KTParsedKeyPath *aKeyPath;
	while (aKeyPath = [keyPathsEnumerator nextObject])
	{
		[[aKeyPath parsedObject] removeObserver:self forKeyPath:[aKeyPath keyPath]];
	}
	[component removeAllParsedKeyPaths];
	
	// Stop observing keypaths of its subcomponents
	NSEnumerator *subComponentsEnumerator = [[component allSubComponents] objectEnumerator];
	KTParsedWebViewComponent *aSubComponent;
	while (aSubComponent = [subComponentsEnumerator nextObject])
	{
		keyPathsEnumerator = [[aSubComponent parsedKeyPaths] objectEnumerator];
		while (aKeyPath = [keyPathsEnumerator nextObject])
		{
			[[aKeyPath parsedObject] removeObserver:self forKeyPath:[aKeyPath keyPath]];
		}
		
		// While we're at it, remove the subComponent from our dictionary
		[myWebViewComponents removeObjectsForKeys:[myWebViewComponents allKeysForObject:aSubComponent]];
	}
	
	// Release the component from the hierarchy
	[component removeAllSubComponents];
}

#pragma mark -
#pragma mark Page Key Paths

- (void)addParsedKeyPath:(NSString *)keyPath ofObject:(NSObject *)object forParsedComponent:(KTParsedWebViewComponent *)parsedComponent
{
	// Add the keypath to the parsedComponent and observe it
	KTParsedKeyPath *parsedKeyPath = [[KTParsedKeyPath alloc] initWithKeyPath:keyPath ofObject:object];
	if (![[parsedComponent parsedKeyPaths] containsObject:parsedKeyPath])
	{
		[parsedComponent addParsedKeyPath:parsedKeyPath];
		[object addObserver:self forKeyPath:keyPath options:0 context:NULL];
	}
	[parsedKeyPath release];
}

- (void)addParsedKeyPath:(NSString *)keyPath ofObject:(NSObject *)object forParser:(KTHTMLParser *)parser
{
	// Add the keypath to the parsedComponent and observe it
	KTParsedWebViewComponent *parsedComponent = [self webViewComponentForParser:parser];
	[self addParsedKeyPath:keyPath ofObject:object forParsedComponent:parsedComponent];
}

// Run through our list of webview components to find any that match the keyPath
- (NSSet *)webViewComponentsWithParsedKeyPath:(KTParsedKeyPath *)keyPath
{
	NSMutableSet *result = [NSMutableSet setWithCapacity:1];
	
	NSEnumerator *componentsEnumerator = [myWebViewComponents objectEnumerator];
	KTParsedWebViewComponent *aComponent;
	while (aComponent = [componentsEnumerator nextObject])
	{
		if ([[aComponent parsedKeyPaths] containsObject:keyPath])
		{
			[result addObject:aComponent];
		}
	}
	
	return result;
}

/*	We are registered to know when the document will close so that key paths can be cleared out first.
 *	Otherwise, one key path is bound to try to access the document and then ... kaboom!
 */
- (void)documentWillClose:(NSNotification *)notification
{
	[self setMainWebViewComponent:nil];
	[self setWebViewNeedsRefresh:NO];
}

@end
