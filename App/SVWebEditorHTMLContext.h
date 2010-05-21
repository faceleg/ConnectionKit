//
//  SVWebEditorHTMLContext.h
//  Sandvox
//
//  Created by Mike on 05/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVHTMLContext.h"


@class SVWebEditorViewController, SVDOMController, SVSidebarDOMController;
@class SVContentObject, SVSidebar, SVSidebarPageletsController;
@class KSObjectKeyPathPair, SVMediaRecord;


@interface SVWebEditorHTMLContext : SVHTMLContext
{
  @private
    NSMutableArray  *_DOMControllers;
    SVDOMController *_currentDOMController;  // weak ref
    
    NSMutableSet    *_dependencies;
    
    NSMutableSet    *_media;
    
    SVSidebarDOMController      *_sidebarDOMController;
    SVSidebarPageletsController *_sidebarPageletsController;
    
    SVWebEditorViewController   *_viewController;   // weak ref
}

- (NSArray *)DOMControllers;    // the top-level controllers, with sub-controllers descending from them

- (void)addDependency:(KSObjectKeyPathPair *)pair;
@property(nonatomic, copy, readonly) NSSet *dependencies;


#pragma mark Media
- (NSSet *)media;


#pragma mark Sidebar
@property(nonatomic, retain, readonly) SVSidebarDOMController *sidebarDOMController;
@property(nonatomic, retain) SVSidebarPageletsController *sidebarPageletsController;


#pragma mark View Controller
@property(nonatomic, assign) SVWebEditorViewController *webEditorViewController;


#pragma mark Low-level controllers
// Ignored by regular contexts. Call one of the -didEndWriting… methods after
- (void)willBeginWritingObjectWithDOMController:(SVDOMController *)controller;


@end


#pragma mark -


@interface SVHTMLContext (SVEditing)

#pragma mark Text Blocks
- (void)willBeginWritingHTMLTextBlock:(SVHTMLTextBlock *)textBlock;
- (void)didEndWritingHTMLTextBlock;


#pragma mark Sidebar
- (void)willBeginWritingSidebar:(SVSidebar *)sidebar; // call -didEndWritingGraphic after
// The context may provide its own controller for sidebar pagelets (pre-sorted etc.) If so, please use it.
- (NSArrayController *)cachedSidebarPageletsController;


#pragma mark Current Item
- (SVDOMController *)currentItem;


@end
