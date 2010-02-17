//
//  SVWebEditorItem.h
//  Sandvox
//
//  Created by Mike on 24/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//
//  Concrete implementation of the SVWebEditorItem protocol


#import "KSDOMController.h"
#import "SVSelectionBorder.h"


@class SVWebEditorView;


@interface SVWebEditorItem : KSDOMController
{
  @private
    // Tree
    NSArray         *_childControllers;
    SVWebEditorItem *_parentController;
    
    BOOL    _selected;
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
- (unsigned int)resizingMask;

@property(nonatomic, getter=isSelected) BOOL selected;

- (NSArray *)selectableAncestors;   // Search up the tree for all parent items returning YES for -isSelectable


#pragma mark Searching the Tree

- (SVWebEditorItem *)childItemForDOMNode:(DOMNode *)node;
- (SVWebEditorItem *)descendantItemForDOMNode:(DOMNode *)node;  // guaranteed a match (returns self if nothing else fits)

- (SVWebEditorItem *)descendantItemWithRepresentedObject:(id)object;

- (NSEnumerator *)enumerator;


#pragma mark NSResponder Aping
// Nothing to do since we now inherit from NSResponder!


#pragma mark Resizing
- (unsigned int)resizingMask;   // default is 0
- (NSInteger)resizeByMovingHandle:(SVGraphicHandle)handle toPoint:(NSPoint)point;


#pragma mark Drawing
// dirtyRect is expressed in the view's co-ordinate system. view is not necessarily the context being drawn into (but generally is)
- (void)drawRect:(NSRect)dirtyRect inView:(NSView *)view;
- (NSRect)drawingRect;  // expressed in our DOM node's document view's coordinates

- (SVSelectionBorder *)newSelectionBorder;


#pragma mark Debugging
- (NSString *)descriptionWithIndent:(NSUInteger)level;
- (NSString *)blurb;

@end
