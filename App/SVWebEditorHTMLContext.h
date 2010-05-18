//
//  SVWebEditorHTMLContext.h
//  Sandvox
//
//  Created by Mike on 05/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVHTMLContext.h"


@class SVDOMController, SVSidebarDOMController;
@class SVContentObject, SVSidebar, SVSidebarPageletsController;
@class KSObjectKeyPathPair, SVMediaRecord;


@interface SVWebEditorHTMLContext : SVHTMLContext
{
    NSMutableArray  *_items;
    SVDOMController *_currentItem;  // weak ref
    
    NSMutableSet    *_objectKeyPathPairs;
    
    NSMutableSet    *_media;
    
    SVSidebarDOMController      *_sidebarDOMController;
    SVSidebarPageletsController *_sidebarPageletsController;
}

- (NSArray *)webEditorItems;

- (void)addDependency:(KSObjectKeyPathPair *)pair;
@property(nonatomic, copy, readonly) NSSet *dependencies;


#pragma mark Media
- (NSSet *)media;


#pragma mark Sidebar
@property(nonatomic, retain, readonly) SVSidebarDOMController *sidebarDOMController;
@property(nonatomic, retain) SVSidebarPageletsController *sidebarPageletsController;


#pragma mark Low-level controllers
// Ignored by regular contexts. Call one of the -didEndWriting… methods after
- (void)willBeginWritingContentObject:(SVContentObject *)object;
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
