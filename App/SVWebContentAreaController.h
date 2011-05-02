//
//  SVDocContentViewController.h
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import <BWToolkitFramework/BWToolkitFramework.h>

#import "SVWebEditorViewController.h"
#import "KSInspector.h"


// myViewTypes
typedef enum {
	KTStandardWebView,
	KTWithoutStylesView,
	KTSourceCodeView,
	KTPreviewSourceCodeView,	// in Debug menu
	KTDOMSourceView,
	KTRSSView,					// Unimplemented
	KTRSSSourceView,
} KTWebViewViewType;


@protocol SVWebContentAreaControllerDelegate;
@class SVURLPreviewViewController, SVLoadingPlaceholderViewController;


@interface SVWebContentAreaController : BWTabViewController <KSInspection, SVWebEditorViewControllerDelegate>
{
  @private
    SVWebEditorViewController           *_webEditorViewController;
    SVURLPreviewViewController          *_webPreviewController;
    NSViewController                    *_sourceViewController;
    SVLoadingPlaceholderViewController  *_placeholderViewController;
    NSViewController                    *_multipleSelectionPlaceholder;
    
    NSArray *_selectedPages;
    
    NSViewController    *_selectedViewControllerWhenReady;
    KTWebViewViewType   _viewType;
    
    id <SVWebContentAreaControllerDelegate> _delegate;  // weak ref
}

#pragma mark Pages
// Set this and the webview/source list view will be updated to match. Can even bind it!
@property(nonatomic, copy) NSArray *selectedPages;
- (SVSiteItem *)selectedPage;   // returns nil if more than one page is selected


#pragma mark View Type

@property(nonatomic) KTWebViewViewType viewType;
- (IBAction)selectWebViewViewType:(id)sender;

- (NSViewController *)viewControllerForSiteItem:(SVSiteItem *)item;


#pragma mark View Controllers

@property(nonatomic, retain, readonly) SVWebEditorViewController *webEditorViewController;

// If the controller is ready, displays it immediately. If not, the existing view remains on screen until either the new view is ready. If too much time elapses before the new view is ready, a placeholder is swapped in the meantime. Passing nil is fine and will switch to the placeholder view
@property(nonatomic, assign) NSViewController *selectedViewControllerWhenReady;

- (void)presentLoadingViewController;


#pragma mark Delegate
@property(nonatomic, assign) id <SVWebContentAreaControllerDelegate> delegate;


@end


#pragma mark -


@protocol SVWebContentAreaControllerDelegate
@end


#pragma mark -


@interface NSViewController (SVSiteItemViewController)

/*!
 *  Called by the Web Content Area Controller when:
 *  A)  The user changes view type
 *  B)  The selected pages change
 *
 *  So this is a good point to update your view to reflect the selection.
 *  If the view is not ready yet (perhaps it's an asynchronous update process), return NO. Then call -setSelectedViewController:self on controller when done.
 *  Default implementation always returns YES.
 */
- (BOOL)viewShouldAppear:(BOOL)animated
webContentAreaController:(SVWebContentAreaController *)controller;

@end
