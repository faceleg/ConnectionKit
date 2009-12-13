//
//  SVWebEditorViewController.h
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KSWebViewController.h"
#import "SVHTMLTemplateParser.h"
#import "SVWebEditorView.h"


@class KTPage, SVHTMLContext, SVDOMController, SVWebEditorTextController;
@class SVWebContentObjectsController, SVWebEditorMainDOMController;
@protocol KSCollectionController;
@protocol SVWebEditorViewControllerDelegate;


@interface SVWebEditorViewController : KSWebViewController <SVWebEditorViewDataSource, SVWebEditorViewDelegate, SVHTMLTemplateParserDelegate>
{
    // View
    SVWebEditorView *_webEditorView;
    
    // Model
    KTPage                      *_page;
    SVHTMLContext               *_context;
    
    NSSet                           *_selectableObjects;
    SVWebContentObjectsController   *_selectableObjectsController;
    
    // Controllers
    NSArray         *_textAreas;
    
    NSArray             *_contentItems;
    DOMHTMLDivElement   *_sidebarDiv;
    NSArray             *_sidebarPageletItems;
    
    // Loading
    BOOL                            _needsUpdate, _willUpdate;
    BOOL                            _isUpdating;
    NSRect                          _visibleRect;
    SVWebEditorMainDOMController    *_mainDOMController;
    
    NSSet   *_pageDependencies;
    
    // Delegate
    id <SVWebEditorViewControllerDelegate>  _delegate;  // weak ref
}


#pragma mark View
@property(nonatomic, retain) SVWebEditorView *webEditorView;


#pragma mark Updating

- (void)update;
@property(nonatomic, readonly, getter=isUpdating) BOOL updating;

@property(nonatomic, readonly) BOOL needsUpdate;
- (void)setNeedsUpdate;
- (void)updateIfNeeded; // only updates what's needed, so could just be a handful of DOM controllers

@property(nonatomic, retain, readonly) SVDOMController *mainDOMController;


#pragma mark Content

// Everything here should be KVO-compliant
@property(nonatomic, retain) KTPage *page;  // reloads
@property(nonatomic, retain, readonly) id <KSCollectionController> selectedObjectsController;
@property(nonatomic, retain, readonly) SVHTMLContext *HTMLContext;


#pragma mark Text Areas

// An array of SVTextBlock objects, one per text block created when setting up the page
@property(nonatomic, copy, readonly) NSArray *textAreas;
// A series of methods for retrieving the Text Block to go with a bit of the webview
- (SVWebEditorTextController *)textAreaForDOMNode:(DOMNode *)node;
- (SVWebEditorTextController *)textAreaForDOMRange:(DOMRange *)range;


#pragma mark Graphics

@property(nonatomic, copy, readonly) NSArray *contentItems;
- (id <SVWebEditorItem>)contentItemForObject:(id)object;
@property(nonatomic, copy, readonly) NSArray *sidebarPageletItems;


#pragma mark Content Objects

- (IBAction)insertPagelet:(id)sender;
- (IBAction)insertPageletInSidebar:(id)sender;
- (IBAction)insertElement:(id)sender;

- (IBAction)insertSiteTitle:(id)sender;
- (IBAction)insertSiteSubtitle:(id)sender;
- (IBAction)insertPageTitle:(id)sender;
- (IBAction)insertPageletTitle:(id)sender;
- (IBAction)insertFooter:(id)sender;


#pragma mark Delegate
@property(nonatomic, assign) id <SVWebEditorViewControllerDelegate> delegate;


@end


#pragma mark -


@protocol SVWebEditorViewControllerDelegate

- (void)webEditorViewControllerDidFirstLayout:(SVWebEditorViewController *)sender;

// The controller is not in a position to open a page by itself; it lets somebody else decide how to
- (void)webEditorViewController:(SVWebEditorViewController *)sender openPage:(KTPage *)page;

@end

