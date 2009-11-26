//
//  SVDocContentViewController.h
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KSTabViewController.h"

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
@class SVLoadingPlaceholderViewController;


@interface SVWebContentAreaController : KSTabViewController <KSInspection, SVWebEditorViewControllerDelegate>
{
  @private
    SVWebEditorViewController           *_webEditorViewController;
    NSViewController                    *_sourceViewController;
    SVLoadingPlaceholderViewController  *_placeholderViewController;
    
    NSArray *_selectedPages;
    
    KTWebViewViewType   _viewType;
    
    id <SVWebContentAreaControllerDelegate> _delegate;  // weak ref
}

#pragma mark Pages
// Set this and the webview/source list view will be updated to match. Can even bind it!
@property(nonatomic, copy) NSArray *selectedPages;


#pragma mark View Type
@property(nonatomic) KTWebViewViewType viewType;
- (IBAction)selectWebViewViewType:(id)sender;

- (NSViewController *)viewControllerForViewType:(KTWebViewViewType)viewType;


#pragma mark View Controllers
@property(nonatomic, retain, readonly) SVWebEditorViewController *webEditorViewController;


#pragma mark Delegate
@property(nonatomic, assign) id <SVWebContentAreaControllerDelegate> delegate;


@end


@protocol SVWebContentAreaControllerDelegate

- (void)webContentAreaControllerDidChangeTitle:(SVWebContentAreaController *)controller;
@end