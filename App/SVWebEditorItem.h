//
//  SVWebEditorItem.h
//  Sandvox
//
//  Created by Mike on 24/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//
//  Concrete implementation of the SVWebEditorItem protocol


#import "KSDOMController.h"


@class SVWebEditorView;


@interface SVWebEditorItem : KSDOMController
{
  @private
    // Tree
    NSArray         *_childControllers;
    SVWebEditorItem *_parentController;
}

@property(nonatomic, assign, readonly) SVWebEditorView *webEditor;  // NOT KVO-compliant


#pragma mark Tree
@property(nonatomic, copy) NSArray *childWebEditorItems;
@property(nonatomic, assign) SVWebEditorItem *parentWebEditorItem;  // don't call setter directly
- (void)addChildWebEditorItem:(SVWebEditorItem *)controller;
- (void)removeFromParentWebEditorItem;


#pragma mark Selection

- (BOOL)isSelectable;   // default is YES. Subclass for more complexity, shouldn't worry about KVO
- (BOOL)isEditable;
- (unsigned int)resizingMask;   // default is 0

- (NSArray *)selectableAncestors;   // Search up the tree for all parent items returning YES for -isSelectable


#pragma mark Searching the Tree

- (SVWebEditorItem *)childItemForDOMNode:(DOMNode *)node;
- (SVWebEditorItem *)descendantItemForDOMNode:(DOMNode *)node;  // guaranteed a match (returns self if nothing else fits)

- (SVWebEditorItem *)descendantItemWithRepresentedObject:(id)object;

- (NSEnumerator *)enumerator;


#pragma mark Debugging
- (NSString *)descriptionWithIndent:(NSUInteger)level;
- (NSString *)blurb;

@end
