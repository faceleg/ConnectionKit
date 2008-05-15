//
//  KTDocWebViewController.h
//  Marvel
//
//  Created by Mike on 13/09/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


// myViewTypes
typedef enum {
	KTStandardWebView,
	KTWithoutStylesView,
	KTSourceCodeView,
	KTPreviewSourceCodeView,	// Unimplemented
	KTDOMSourceView,
	KTRSSView,					// Unimplemented
	KTRSSSourceView,
	KTHTMLValidationView
} KTWebViewViewType;


@class KTParsedWebViewComponent;
@class KTWebViewTextBlock, KTWebViewUndoManagerProxy;
@class KTHTMLParser;
@class KTInlineImageElement;
@class KTPagelet;
@class CIFilter;
@class KTAbstractElement;
@class KTDocument;
@class KTDocWindowController;
@class KTAsyncOffscreenWebViewController;

@interface KTDocWebViewController : NSObject
{
	IBOutlet WebView				*webView;
	IBOutlet NSTextView				*oSourceTextView;
	
	
	@private
	
	WebView					*myWebView;
	KTDocWindowController	*myWindowController;
	
	DOMHTMLElement			*myElementWaitingForFragmentLoad;
	KTAsyncOffscreenWebViewController				*myAsyncOffscreenWebViewController;
	
	// Refreshing
	KTParsedWebViewComponent	*myMainWebViewComponent;
	NSMutableDictionary			*myWebViewComponents;
	
	BOOL						myWebViewNeedsReload;
	
	NSCountedSet				*mySuspendedKeyPaths;
	NSMutableSet				*mySuspendedKeyPathsAwaitingRefresh;
	
	
	
	NSString	*mySavedPageletStyle;
	DOMHTMLElement					*mySelectedPageletHTMLElement;
	
	BOOL myWebViewIsLoading;
	
		
	WebScriptObject					*myWindowScriptObject;
	
	KTWebViewViewType	myViewType;
	
	// Animation
	NSWindow						*myAnimationCoverWindow;
	NSTimer							*myAnimationTimer;
	CIFilter						*myTransitionFilter;
	NSPoint							myAnimateStartingPoint;
	NSTimeInterval					myBaseTime;
	NSTimeInterval					myTotalAnimationTime;
	
	// Resources
	unsigned int myResourceCount;
	unsigned int myResourceCompletedCount;
	unsigned int myResourceFailedCount;
	
	
	// Editing
	KTWebViewTextBlock	*myTextEditingBlock;
	KTWebViewUndoManagerProxy	*myUndoManagerProxy;
	
	NSMutableDictionary	*myInlineImageNodes;
	NSMutableDictionary *myInlineImageElements;
}

// Accessors
- (WebView *)webView;
- (void)setWebView:(WebView *)webView;	// No-one should have to call this.

- (DOMHTMLElement *)elementWaitingForFragmentLoad;
- (void)setElementWaitingForFragmentLoad:(DOMHTMLElement *)anElementWaitingForFragmentLoad;
- (KTAsyncOffscreenWebViewController *)asyncOffscreenWebViewController;
- (void)setAsyncOffscreenWebViewController:(KTAsyncOffscreenWebViewController *)anAsyncOffscreenWebViewController;

- (NSTextView *)sourceCodeTextView;

- (KTDocWindowController *)windowController;	// Weak reference
- (void)setWindowController:(KTDocWindowController *)windowController;	// Don't call this.
- (KTDocument *)document;

- (NSString *)savedPageletStyle;
- (void)setSavedPageletStyle:(NSString *)aSavedPageletStyle;

- (DOMHTMLElement *)selectedPageletHTMLElement;
- (void)setSelectedPageletHTMLElement:(DOMHTMLElement *)aSelectedPageletHTMLElement;

- (KTWebViewViewType)viewType;
- (void)setViewType:(KTWebViewViewType)aViewType;

- (NSWindow *)animationCoverWindow;
- (void)setAnimationCoverWindow:(NSWindow *)anAnimationCoverWindow;

- (NSTimer *)animationTimer;
- (void)setAnimationTimer:(NSTimer *)anAnimationTimer;

- (CIFilter *)transitionFilter;
- (void)setTransitionFilter:(CIFilter *)aTransitionFilter;

- (NSTimeInterval)baseTime;
- (void)setBaseTime:(NSTimeInterval)aBaseTime;

- (NSTimeInterval)totalAnimationTime;
- (void)setTotalAnimationTime:(NSTimeInterval)aTotalAnimationTime;

- (WebScriptObject *)windowScriptObject;
- (void)setWindowScriptObject:(WebScriptObject *)aWindowScriptObject;



// Updating
- (void)updateWebViewAnimated;

// Other
- (void)selectPagelet:(KTPagelet *)aPagelet;
- (void)setHilite:(BOOL)inHilite onHTMLElement:(DOMHTMLElement *)aSelectedPageletHTMLElement;

@end


@interface KTDocWebViewController (Refreshing)

// Content loading
- (BOOL)webViewNeedsRefresh;
- (void)setWebViewNeedsRefresh:(BOOL)needsRefresh;

- (void)refreshWebView;
- (void)refreshWebViewIfNeeded;

- (void)suspendWebViewRefreshingForKeyPath:(NSString *)keyPath ofObject:(id)anObject;
- (void)resumeWebViewRefreshingForKeyPath:(NSString *)keyPath ofObject:(id)anObject;
- (void)resumeWebViewRefreshing;

// Web View component hierarchy
- (KTParsedWebViewComponent *)mainWebViewComponent;
- (void)setMainWebViewComponent:(KTParsedWebViewComponent *)component;

- (void)addParsedKeyPath:(NSString *)keyPath
				ofObject:(NSObject *)object
			   forParser:(KTHTMLParser *)parser;

- (void) spliceElement:(DOMHTMLElement *)loadedBody;

@end

@interface KTDocWebViewController (Editing)

- (void)processEditableElementsFromElement:(DOMElement *)aDOMElement;

// Editing status
- (BOOL)webViewIsEditing;
- (KTWebViewTextBlock *)currentTextEditingBlock;
- (BOOL)commitEditing;

- (KTInlineImageElement *)inlineImageElementForNode:(DOMHTMLImageElement *)node
										  container:(KTAbstractElement *)container;

// Links
- (BOOL)validateCreateLinkItem:(id <NSValidatedUserInterfaceItem>)item title:(NSString **)title;

- (BOOL)webKitValidateMenuItem:(NSMenuItem *)menuItem;


@end
