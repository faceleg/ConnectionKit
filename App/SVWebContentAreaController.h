//
//  SVDocContentViewController.h
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <BWToolkitFramework/BWToolkitFramework.h>

#import "SVSiteItemViewController.h"
#import "SVWebEditorViewController.h"
#import "KSInspector.h"


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


@protocol SVWebContentAreaControllerDelegate;
@class SVURLPreviewViewController, SVLoadingPlaceholderViewController;


@interface SVWebContentAreaController : BWTabViewController <KSInspection, SVSiteItemViewControllerDelegate, SVWebEditorViewControllerDelegate>
{
  @private
    SVWebEditorViewController           *_webEditorViewController;
    SVURLPreviewViewController          *_webPreviewController;
    NSViewController                    *_sourceViewController;
    SVLoadingPlaceholderViewController  *_placeholderViewController;
    
    NSArray *_selectedPages;
    
    NSViewController <SVSiteItemViewController> *_selectedViewControllerWhenReady;
    KTWebViewViewType                           _viewType;
    
    id <SVWebContentAreaControllerDelegate> _delegate;  // weak ref
}

#pragma mark Pages
// Set this and the webview/source list view will be updated to match. Can even bind it!
@property(nonatomic, copy) NSArray *selectedPages;


#pragma mark View Type

@property(nonatomic) KTWebViewViewType viewType;
- (IBAction)selectWebViewViewType:(id)sender;

- (NSViewController <SVSiteItemViewController> *)viewControllerForSiteItem:(SVSiteItem *)item;


#pragma mark View Controllers

@property(nonatomic, retain, readonly) SVWebEditorViewController *webEditorViewController;

// If the controller is ready, displays it immediately. If not, the existing view remains on screen until either the new view is ready. If too much time elapses before the new view is ready, a placeholder is swapped in the meantime. Passing nil is fine and will switch to the placeholder view
@property(nonatomic, retain) NSViewController <SVSiteItemViewController> *selectedViewControllerWhenReady;

- (void)presentLoadingViewController;


#pragma mark Delegate
@property(nonatomic, assign) id <SVWebContentAreaControllerDelegate> delegate;


@end


@protocol SVWebContentAreaControllerDelegate
@end
