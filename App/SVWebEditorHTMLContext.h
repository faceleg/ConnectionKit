//
//  SVWebEditorHTMLContext.h
//  Sandvox
//
//  Created by Mike on 05/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVHTMLContext.h"


@class SVWebEditorItem, SVDOMController, KSObjectKeyPathPair;


@interface SVWebEditorHTMLContext : SVHTMLContext
{
    NSMutableArray  *_items;
    SVWebEditorItem *_currentItem;  // weak ref
    
    NSMutableSet    *_objectKeyPathPairs;
}

- (NSArray *)webEditorItems;

- (void)addDependency:(KSObjectKeyPathPair *)pair;
@property(nonatomic, copy, readonly) NSSet *dependencies;

@end


#pragma mark -


@interface SVHTMLContext (SVEditing)

#pragma mark Text Blocks
- (void)willBeginWritingHTMLTextBlock:(SVHTMLTextBlock *)textBlock;
- (void)didEndWritingHTMLTextBlock;


#pragma mark Low-level controllers
// Ignored by regular contexts. Call one of the -didEndWriting… methods after
- (void)willBeginWritingObjectWithDOMController:(SVDOMController *)controller;

@end