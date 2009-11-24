//
//  SVWebViewLoadingController.h
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KSTabViewController.h"
#import "SVWebEditorViewController.h"


@protocol KSCollectionController;


@protocol SVWebViewLoadControllerDelegate;
@interface SVWebEditorLoadController : KSTabViewController <SVWebEditorViewControllerDelegate>
{
  @private
    SVWebEditorViewController   *_webEditorViewController;
    NSViewController            *_webViewLoadingPlaceholder;
    
    KTPage              *_page;
    NSSet               *_selectableObjects;
    NSArrayController   *_selectableObjectsController;
    
    BOOL    _needsLoad;
    NSSet   *_pageDependencies;
    
    id <SVWebViewLoadControllerDelegate>    _delegate;  // weak ref
}

// You should use this to create a controller as it will internally create the correct subcontrollers
- (id)init;

@property(nonatomic, retain, readonly) SVWebEditorViewController *webEditorViewController;
//@property(nonatomic, retain, readonly) SVWebEditorViewController *secondaryWebViewController;

// Setting the page will automatically mark controller as needsLoad = YES
@property(nonatomic, retain) KTPage *page;
@property(nonatomic, retain, readonly) id <KSCollectionController> selectableObjectsController;


#pragma mark Loading
- (void)load;

@property(nonatomic, readonly) BOOL needsLoad;
- (void)setNeedsLoad;
- (void)loadIfNeeded;


#pragma mark Delegate
@property(nonatomic, assign) id <SVWebViewLoadControllerDelegate> delegate;

@end


#pragma mark -


@protocol SVWebViewLoadControllerDelegate

- (void)loadControllerDidChangeTitle:(SVWebEditorLoadController *)controller;

// The controller is not in a position to open a page by itself; it lets somebody else decide how to
- (void)loadController:(SVWebEditorLoadController *)sender openPage:(KTPage *)page;
@end

