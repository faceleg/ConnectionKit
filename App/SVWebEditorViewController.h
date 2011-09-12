//
//  SVWebEditorViewController.h
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "KSWebViewController.h"

#import "SVHTMLTemplateParser.h"
#import "WEKWebEditorView.h"
#import "SVWebEditorHTMLContext.h"
#import "SVWebContentObjectsController.h"


extern NSString *sSVWebEditorViewControllerWillUpdateNotification;


@class KTPage, SVDOMController, SVContentDOMController, SVTextDOMController;
@class KTHTMLEditorController, SVWebContentAreaController;
@protocol KSCollectionController;
@protocol SVWebEditorViewControllerDelegate;


@interface SVWebEditorViewController : KSWebViewController <WEKWebEditorDataSource, WEKWebEditorDelegate, SVHTMLTemplateParserDelegate>
{
    // View/Presentation
    WEKWebEditorView            *_webEditorView;
    BOOL                        _readyToAppear;
    SVWebContentAreaController  *_contentAreaController;    // weak ref
    
    // Model
    SVWebEditorHTMLContext      *_context;
    
    // Selection
    NSObjectController              *_pageController;
    SVWebContentObjectsController   *_graphicsController;
    BOOL                            _isChangingSelection;
    
    // Controllers
    SVContentDOMController  *_contentItem;
	
    // Updating
    BOOL                    _needsUpdate, _willUpdate, _reload;
    NSUInteger              _updatesCount;
    NSRect                  _visibleRect;
    SVWebEditorTextRange    *_selectionToRestore;
    
    // Loading
    KTPage  *_loadedPage;
    BOOL    _articleShouldBecomeFocusedAfterNextLoad;
    
    // Drag/drop
    NSObject        *_draggingDestination;  // weak ref
    NSDragOperation _dropOp;
        
    // Delegate
    id <SVWebEditorViewControllerDelegate>  _delegate;  // weak ref
}


#pragma mark View
@property(nonatomic, retain) WEKWebEditorView *webEditor;


#pragma mark Updating

- (void)update;
@property(nonatomic, readonly, getter=isUpdating) BOOL updating;

@property(nonatomic, readonly) BOOL needsUpdate;
- (void)setNeedsUpdate;
- (void)updateIfNeeded; // only updates what's needed, so could just be a handful of DOM controllers

- (void)willUpdate;
- (void)didUpdate;


#pragma mark Loading
- (void)loadPage:(KTPage *)page;
- (KTPage *)loadedPage; // the last page to successfully load into Web Editor
@property(nonatomic) BOOL articleShouldBecomeFocusedAfterNextLoad;


#pragma mark Content

// Everything here should be KVO-compliant
@property(nonatomic, retain, readonly) NSObjectController *pageController;
@property(nonatomic, retain, readonly) SVWebContentObjectsController *graphicsController;

@property(nonatomic, retain, readonly) SVContentDOMController *contentDOMController;
@property(nonatomic, retain, readonly) SVWebEditorHTMLContext *HTMLContext;

- (void)registerWebEditorItem:(WEKWebEditorItem *)item;  // recurses through, registering descendants too


#pragma mark Text Areas
// A series of methods for retrieving the Text Block to go with a bit of the webview
- (SVTextDOMController *)textAreaForDOMNode:(DOMNode *)node;
- (SVTextDOMController *)textAreaForDOMRange:(DOMRange *)range;
- (WEKWebEditorItem *)articleDOMController;


#pragma mark Content Objects

- (IBAction)insertPagelet:(id)sender;
- (IBAction)insertFile:(id)sender;

- (IBAction)insertPageletTitle:(id)sender;

- (IBAction)editRawHTMLInSelectedBlock:(id)sender;


#pragma mark Graphic Placement
- (IBAction)placeInline:(id)sender;
- (IBAction)placeInline:(id)sender;    // tells all selected graphics to become placed as block
- (IBAction)placeAsCallout:(id)sender;
- (IBAction)placeInSidebar:(id)sender;


#pragma mark Action Forwarding
- (BOOL)tryToMakeSelectionPerformAction:(SEL)action with:(id)anObject;


#pragma mark Undo

- (void)textDOMControllerDidChangeText:(SVTextDOMController *)controller;


#pragma mark Delegate
@property(nonatomic, assign) id <SVWebEditorViewControllerDelegate> delegate;


@end


#pragma mark -


@protocol SVWebEditorViewControllerDelegate <NSObject>

// The controller is not in a position to open a page by itself; it lets somebody else decide how to
- (void)webEditorViewController:(SVWebEditorViewController *)sender openSiteItem:(SVSiteItem *)page;

@optional
- (void)webEditorViewControllerWillUpdate:(NSNotification *)notification;

@end


#pragma mark -


@interface WEKWebEditorItem (SVWebEditorViewController)
- (NSObject *)hitTestDOMNode:(DOMNode *)node
          draggingPasteboard:(NSPasteboard *)pasteboard;
@end


