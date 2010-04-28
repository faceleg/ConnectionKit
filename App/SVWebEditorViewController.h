//
//  SVWebEditorViewController.h
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KSWebViewController.h"

#import "SVSiteItemViewController.h"
#import "SVHTMLTemplateParser.h"
#import "SVWebEditorView.h"


extern NSString *sSVWebEditorViewControllerWillUpdateNotification;


@class KTPage, SVWebEditorHTMLContext, SVDOMController, SVTextDOMController;
@class SVWebContentObjectsController;
@protocol KSCollectionController;
@protocol SVWebEditorViewControllerDelegate;


@interface SVWebEditorViewController : KSWebViewController <SVSiteItemViewController, SVWebEditorDataSource, SVWebEditorDelegate, SVHTMLTemplateParserDelegate>
{
    // View
    SVWebEditorView *_webEditorView;
    BOOL            _readyToAppear;
    
    // Model
    KTPage                      *_page;
    SVWebEditorHTMLContext      *_context;
    
    SVWebContentObjectsController   *_selectableObjectsController;
    
    // Controllers
    NSMutableArray  *_textDOMControllers;
    
    DOMHTMLDivElement   *_sidebarDiv;
    NSArray             *_sidebarPageletItems;
    
    // Loading
    BOOL                    _needsUpdate, _willUpdate, _autoupdate;
    BOOL                    _isUpdating;
    NSRect                  _visibleRect;
    SVWebEditorTextRange    *_selectionToRestore;
    
    NSSet   *_pageDependencies;
    
    // Delegate
    id <SVWebEditorViewControllerDelegate>  _delegate;  // weak ref
}


#pragma mark View
@property(nonatomic, retain) SVWebEditorView *webEditor;


#pragma mark Updating

- (void)update;
@property(nonatomic, readonly, getter=isUpdating) BOOL updating;

@property(nonatomic, readonly) BOOL needsUpdate;
- (void)setNeedsUpdate;
- (void)updateIfNeeded; // only updates what's needed, so could just be a handful of DOM controllers

@property(nonatomic, getter=isAutoupdate) BOOL autoupdate;  // like -[NSWindow setAutodisplay:]. Not actually implemented yet!

- (void)willUpdate;
- (void)didUpdate;  // if an asynchronous update, called after the update finishes


#pragma mark Content

// Everything here should be KVO-compliant
@property(nonatomic, retain) KTPage *page;  // reloads
@property(nonatomic, retain, readonly) NSArrayController *selectedObjectsController;
@property(nonatomic, readonly) SVTextDOMController *focusedTextController;    // KVO-compliant

@property(nonatomic, retain, readonly) SVWebEditorHTMLContext *HTMLContext;

- (void)registerWebEditorItem:(SVWebEditorItem *)item;  // recurses through, registering descendants too


#pragma mark Text Areas

// An array of SVTextBlock objects, one per text block created when setting up the page
@property(nonatomic, copy, readonly) NSArray *textAreas;
// A series of methods for retrieving the Text Block to go with a bit of the webview
- (SVTextDOMController *)textAreaForDOMNode:(DOMNode *)node;
- (SVTextDOMController *)textAreaForDOMRange:(DOMRange *)range;


#pragma mark Graphics

@property(nonatomic, copy, readonly) NSArray *sidebarPageletItems;


#pragma mark Content Objects

- (IBAction)insertPagelet:(id)sender;
- (IBAction)insertPageletInSidebar:(id)sender;
- (IBAction)insertElement:(id)sender;
- (IBAction)insertFile:(id)sender;

- (IBAction)insertPageletTitle:(id)sender;


#pragma mark Action Forwarding
- (BOOL)tryToMakeSelectionPerformAction:(SEL)action with:(id)anObject;


#pragma mark Undo

- (void)textDOMControllerDidChangeText:(SVTextDOMController *)controller;


#pragma mark Delegate
@property(nonatomic, assign) id <SVWebEditorViewControllerDelegate> delegate;


@end


#pragma mark -


@protocol SVWebEditorViewControllerDelegate <SVSiteItemViewControllerDelegate, NSObject>

// The controller is not in a position to open a page by itself; it lets somebody else decide how to
- (void)webEditorViewController:(SVWebEditorViewController *)sender openPage:(KTPage *)page;

@optional
- (void)webEditorViewControllerWillUpdate:(NSNotification *)notification;

@end


#pragma mark -


@interface SVWebEditorView (SVWebEditorViewController)
- (IBAction)placeBlockLevel:(id)sender;    // tells all selected graphics to become placed as block
- (IBAction)placeBlockLevelIfNeeded:(NSButton *)sender; // calls -placeBlockLevel if sender's state is on
@end

