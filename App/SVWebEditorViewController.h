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
#import "WebEditingKit.h"
#import "SVWebEditorHTMLContext.h"


extern NSString *sSVWebEditorViewControllerWillUpdateNotification;

#define sWebViewDependenciesObservationContext @"SVWebViewDependenciesObservationContext"


@class KTPage, SVDOMController, SVTextDOMController;
@class SVWebContentObjectsController, SVWebContentAreaController;
@protocol KSCollectionController;
@protocol SVWebEditorViewControllerDelegate;


@interface SVWebEditorViewController : KSWebViewController <SVSiteItemViewController, WEKWebEditorDataSource, WEKWebEditorDelegate, SVHTMLTemplateParserDelegate>
{
    // View/Presentation
    WEKWebEditorView            *_webEditorView;
    BOOL                        _readyToAppear;
    SVWebContentAreaController  *_contentAreaController;    // weak ref
    
    // Model
    KTPage                      *_page;
    SVWebEditorHTMLContext      *_context;
    
    SVWebContentObjectsController   *_selectableObjectsController;
    
    // Controllers
    WEKWebEditorItem    *_firstResponderItem;
    NSObject            *_draggingDestination;  // weak ref
    
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
@property(nonatomic, retain) WEKWebEditorView *webEditor;


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
@property(nonatomic, retain) WEKWebEditorItem *firstResponderItem;  // like NSWindow.firstResponder

@property(nonatomic, retain, readonly) SVWebEditorHTMLContext *HTMLContext;

- (void)registerWebEditorItem:(WEKWebEditorItem *)item;  // recurses through, registering descendants too


#pragma mark Text Areas

// A series of methods for retrieving the Text Block to go with a bit of the webview
- (SVTextDOMController *)textAreaForDOMNode:(DOMNode *)node;
- (SVTextDOMController *)textAreaForDOMRange:(DOMRange *)range;


#pragma mark Content Objects

- (IBAction)insertPagelet:(id)sender;
- (IBAction)insertPageletInSidebar:(id)sender;
- (IBAction)insertFile:(id)sender;

- (IBAction)insertPageletTitle:(id)sender;


#pragma mark Graphic Placement
- (IBAction)placeInline:(id)sender;
- (IBAction)placeAsBlock:(id)sender;    // tells all selected graphics to become placed as block
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
- (void)webEditorViewController:(SVWebEditorViewController *)sender openPage:(KTPage *)page;

@optional
- (void)webEditorViewControllerWillUpdate:(NSNotification *)notification;

@end


