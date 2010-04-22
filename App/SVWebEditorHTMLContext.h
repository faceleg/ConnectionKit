//
//  SVWebEditorHTMLContext.h
//  Sandvox
//
//  Created by Mike on 05/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVHTMLContext.h"


@class SVWebEditorItem, SVDOMController, KSObjectKeyPathPair, SVMediaRecord;


@interface SVWebEditorHTMLContext : SVHTMLContext
{
    NSMutableArray  *_items;
    SVWebEditorItem *_currentItem;  // weak ref
    
    NSMutableSet    *_objectKeyPathPairs;
    
    NSMutableSet    *_media;
    
    NSArrayController   *_sidebarPageletsController;
}

- (NSArray *)webEditorItems;

- (void)addDependency:(KSObjectKeyPathPair *)pair;
@property(nonatomic, copy, readonly) NSSet *dependencies;


#pragma mark Media
- (NSSet *)media;


#pragma mark Sidebar
@property(nonatomic, retain) NSArrayController *sidebarPageletsController;


@end


#pragma mark -


@interface SVHTMLContext (SVEditing)

#pragma mark Text Blocks
- (void)willBeginWritingHTMLTextBlock:(SVHTMLTextBlock *)textBlock;
- (void)didEndWritingHTMLTextBlock;


#pragma mark Low-level controllers
// Ignored by regular contexts. Call one of the -didEndWriting… methods after
- (void)willBeginWritingObjectWithDOMController:(SVDOMController *)controller;


#pragma mark Sidebar
// The context may provide its own controller for sidebar pagelets (pre-sorted etc.) If so, please use it.
- (NSArrayController *)cachedSidebarPageletsController;

@end
