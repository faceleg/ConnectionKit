//
//  KTDocWebViewController.h
//  Marvel
//
//  Created by Mike on 13/09/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "SVWebContentAreaController.h"


@class KTAbstractElement, KTPage, KTPagelet;
@class KTWebViewComponent;
@class SVHTMLTextBlock, KTWebViewUndoManagerProxy;
@class SVHTMLTemplateParser;
@class KTInlineImageElement;
@class CIFilter;
@class KTDocument;
@class KTDocWindowController;
@class KTAsyncOffscreenWebViewController;


@interface KTDocWebViewController : NSViewController
{
	IBOutlet WebView	*webView;
	IBOutlet NSTextView *oSourceTextView;
	
	
	@private
	
    DOMHTMLElement                      *myElementWaitingForFragmentLoad;
	KTAsyncOffscreenWebViewController	*myAsyncOffscreenWebViewController;
	
	
	// Loading
    NSSet					*myPages;
    KTWebViewComponent		*myMainWebViewComponent;
    BOOL                    _needsReload;
	unsigned				myLoadingSuspensionCount;
	
	
	
	NSString	*mySavedPageletStyle;
	DOMHTMLElement					*mySelectedPageletHTMLElement;
	
	BOOL myWebViewIsLoading;
	
		
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
	SVHTMLTextBlock				*myTextEditingBlock;
	KTWebViewUndoManagerProxy	*myUndoManagerProxy;
	NSString					*myMidEditHTML;
	
	NSMutableDictionary	*myInlineImageNodes;
	NSMutableDictionary *myInlineImageElements;
}


#pragma mark View
- (WebView *)webView;
- (void)setWebView:(WebView *)webView;	// No-one should have to call this.


#pragma mark Accessors
- (DOMHTMLElement *)elementWaitingForFragmentLoad;
- (void)setElementWaitingForFragmentLoad:(DOMHTMLElement *)anElementWaitingForFragmentLoad;
- (KTAsyncOffscreenWebViewController *)asyncOffscreenWebViewController;
- (void)setAsyncOffscreenWebViewController:(KTAsyncOffscreenWebViewController *)anAsyncOffscreenWebViewController;

- (NSTextView *)sourceCodeTextView;

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




// Updating
- (void)updateWebViewAnimated;

// Other
- (void)selectPagelet:(KTPagelet *)aPagelet;
- (void)setHilite:(BOOL)inHilite onHTMLElement:(DOMHTMLElement *)aSelectedPageletHTMLElement;

@end


#pragma mark -


@interface KTDocWebViewController (Refreshing)

- (NSSet *)pages;
- (void)setPages:(NSSet *)pages;
- (KTPage *)page;

// Content loading
- (BOOL)webViewNeedsReload;
- (void)setWebViewNeedsReload:(BOOL)flag;

- (void)suspendWebViewLoading;
- (void)resumeWebViewLoading;
- (BOOL)webViewLoadingIsSuspended;

- (void)reloadWebView;
- (void)reloadWebViewIfNeeded;

- (void)replaceWebViewComponent:(KTWebViewComponent *)oldComponent withComponent:(KTWebViewComponent *)newComponent;
- (void)spliceElement:(DOMHTMLElement *)loadedBody;	// Private

// Web View component hierarchy
- (KTWebViewComponent *)mainWebViewComponent;
- (void)setMainWebViewComponent:(KTWebViewComponent *)component;

@end


#pragma mark -


@interface KTDocWebViewController (Editing)

- (void)processEditableElementsFromElement:(DOMElement *)aDOMElement;

// Editing status
- (BOOL)webViewIsEditing;
- (SVHTMLTextBlock *)currentTextEditingBlock;
- (BOOL)commitEditing;

- (KTInlineImageElement *)inlineImageElementForNode:(DOMHTMLImageElement *)node
										  container:(KTAbstractElement *)container;

// Links
- (BOOL)validateCreateLinkItem:(id <NSValidatedUserInterfaceItem>)item title:(NSString **)title;

- (IBAction)pasteTextAsMarkup:(id)sender;
- (IBAction)pasteLink:(id)sender;


@end
