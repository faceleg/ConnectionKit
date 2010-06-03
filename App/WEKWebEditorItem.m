//
//  WEKWebEditorItem.m
//  Sandvox
//
//  Created by Mike on 24/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "WEKWebEditorItem.h"
#import "WEKWebEditorView.h"

#import "DOMNode+Karelia.h"


@interface SVWebEditorItemEnumerator : NSEnumerator
{
    NSEnumerator    *_iterator;
}

- (id)initWithItem:(WEKWebEditorItem *)item;

@end


#pragma mark -



@implementation WEKWebEditorItem

- (void)dealloc
{
    [self setChildWebEditorItems:nil];
    
    [super dealloc];
}

#pragma mark Accessors

- (WEKWebEditorView *)webEditor
{
    return [[self parentWebEditorItem] webEditor];
}

#pragma mark Tree

/*  Fairly basic heirarchy maintenance stuff here
 */

@synthesize childWebEditorItems = _childControllers;
- (void)setChildWebEditorItems:(NSArray *)controllers
{
    [[self childWebEditorItems] makeObjectsPerformSelector:@selector(setParentWebEditorItem:)
                                                withObject:nil];
    
    controllers = [controllers copy];
    [_childControllers release]; _childControllers = controllers;
    
    [controllers makeObjectsPerformSelector:@selector(setParentWebEditorItem:)
                                 withObject:self];
}

@synthesize parentWebEditorItem = _parentController;

- (void)setParentWebEditorItem:(WEKWebEditorItem *)item
{
    // When removing from the heirarchy, make sure we're no longer selected
    WEKWebEditorView *webEditorToRemoveFrom = (!item && [self isSelected] ? [self webEditor] : nil);
    
    _parentController = item;
    [self setNextResponder:item];
    
    [webEditorToRemoveFrom deselectItem:self];
}

- (void)addChildWebEditorItem:(WEKWebEditorItem *)controller;
{
    OBPRECONDITION(controller);
    
    if ([controller parentWebEditorItem] == self) return;   // nothing to do
    
    
    NSArray *children = [[self childWebEditorItems] arrayByAddingObject:controller];
    if (!children) children = [NSArray arrayWithObject:controller];
    [_childControllers release]; _childControllers = [children copy];
    
    [controller setParentWebEditorItem:self];
    
    
    // Let delegate know
    WEKWebEditorView *webEditor = [self webEditor];
    [[webEditor delegate] webEditor:webEditor didAddItem:controller];
}

- (void)removeFromParentWebEditorItem;
{
    [self setParentWebEditorItem:nil];
    
    WEKWebEditorItem *parent = [self parentWebEditorItem];
    
    NSMutableArray *children = [[parent childWebEditorItems] mutableCopy];
    [children removeObject:self];
    
    if (parent)
    {
        [parent->_childControllers release]; parent->_childControllers = children;
    }
    else
    {
        [children release];
    }
}

- (NSEnumerator *)enumerator;
{
    NSEnumerator *result = [[[SVWebEditorItemEnumerator alloc] initWithItem:self] autorelease];
    return result;
}

- (void)populateDescendants:(NSMutableArray *)descendants;
{
    [descendants addObjectsFromArray:[self childWebEditorItems]];
    [[self childWebEditorItems] makeObjectsPerformSelector:_cmd withObject:descendants];
}

#pragma mark Selection

- (BOOL)isSelectable;   // default is YES. Subclass for more complexity, shouldn't worry about KVO
{
    return YES;
}

- (BOOL)isEditable { return NO; }

- (void)updateToReflectSelection;
{
    if ([self isSelected] || [self isEditing])
    {
        [[[self HTMLElement] style] setProperty:@"outline"
                                          value:@"1px gray solid"
                                       priority:@""];
    }
    else
    {
        [[[self HTMLElement] style] removeProperty:@"outline"];
    }
}

@synthesize selected = _selected;
- (void)setSelected:(BOOL)selected
{
    _selected = selected;
    
    [[[self HTMLElement] documentView] setNeedsDisplayInRect:[self drawingRect]];
    
    [self updateToReflectSelection];
}

@synthesize editing = _editing;
- (void)setEditing:(BOOL)isEditing;
{
    _editing = isEditing;
    [self updateToReflectSelection];
}

- (BOOL)allowsDirectAccessToWebViewWhenSelected; { return NO; }

- (NSArray *)selectableAncestors;
{
    NSMutableArray *result = [NSMutableArray array];
    
    WEKWebEditorItem *aParentItem = [self parentWebEditorItem];
    while (aParentItem)
    {
        if ([aParentItem isSelectable]) [result addObject:aParentItem];
        aParentItem = [aParentItem parentWebEditorItem];
    }
    
    return result;
}

- (NSArray *)selectableTopLevelDescendants;
{
    NSArray *children = [self childWebEditorItems];
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[children count]];
    
    for (WEKWebEditorItem *anItem in children)
    {
        if ([anItem isSelectable])
        {
            [result addObject:anItem];
        }
        else
        {
            [result addObjectsFromArray:[anItem selectableTopLevelDescendants]];
        }
    }
    
    return result;
}

#pragma mark Searching the Tree

- (WEKWebEditorItem *)hitTestDOMNode:(DOMNode *)node;
{
    OBPRECONDITION(node);
    
    WEKWebEditorItem *result = nil;
    
    if ([node isDescendantOfNode:[self HTMLElement]])
    {
        for (WEKWebEditorItem *anItem in [self childWebEditorItems])
        {
            result = [anItem hitTestDOMNode:node];
            if (result) break;
        }
        
        if (!result) result = self;
    }
    
    return result;
}

- (WEKWebEditorItem *)hitTestRepresentedObject:(id)object;
{
    OBPRECONDITION(object);
    
    id result = ([[self representedObject] isEqual:object] ? self : nil);
    if (!result)
    {
        for (WEKWebEditorItem *anItem in [self childWebEditorItems])
        {
            result = [anItem hitTestRepresentedObject:object];
            if (result) break;
        }
    }
    
    return result;
}

#pragma mark Editing

- (BOOL)tryToRemove;
{
    BOOL result = YES;
    
    DOMHTMLElement *element = [self HTMLElement];
    WEKWebEditorView *webEditor = [self webEditor];
    
    // Check WebEditor is OK with the change
    DOMRange *range = [[element ownerDocument] createRange];
    [range selectNode:element];
            
    result = [webEditor shouldChangeTextInDOMRange:range];
    if (result)
    {
        [element ks_removeFromParentNode];
        [self removeFromParentWebEditorItem];
    }
    
    [range detach];
    
    return result;
}

#pragma mark Dragging Source

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal;
{
    // Copy is supported all the time. But only support moving items while they're in editable HTML
    NSDragOperation result = NSDragOperationCopy;
    if (isLocal && [[self HTMLElement] isContentEditable])
    {
        result = (result | NSDragOperationGeneric | NSDragOperationMove);
    }
    return result;
}

#pragma mark Resizing

- (unsigned int)resizingMask; { return 0; }

- (NSInteger)resizeByMovingHandle:(SVGraphicHandle)handle toPoint:(NSPoint)point;
{    
    SUBCLASSMUSTIMPLEMENT;
    [self doesNotRecognizeSelector:_cmd];
    return handle;
}

#pragma mark Layout

- (NSRect)boundingBox;  // like -[DOMNode boundingBox] but performs union with subcontroller boxes
{
    NSRect result = [[self HTMLElement] boundingBox];
    
    for (WEKWebEditorItem *anItem in [self childWebEditorItems])
    {
        result = NSUnionRect(result, [anItem boundingBox]);
    }
    
    return result;
}

#pragma mark Drawing

- (void)drawRect:(NSRect)dirtyRect inView:(NSView *)view;
{
    if ([self isSelected])
    {
        // Draw if we're in the dirty rect (otherwise drawing can get pretty pricey)
        DOMElement *element = [self HTMLElement];
        NSRect frameRect = [view convertRect:[element boundingBox]
                                    fromView:[element documentView]];

		
		// Selection border and handles
		
        SVSelectionBorder *border = [self newSelectionBorder];
        
        NSRect borderDrawingRect = [border drawingRectForGraphicBounds:frameRect];
        if ([view needsToDrawRect:borderDrawingRect])
        {
            [border setResizingMask:[self resizingMask]];
            [border drawWithGraphicBounds:frameRect inView:view];
        }
        
        [border release];
    }
}

- (NSRect)drawingRect;  // expressed in our DOM node's document view's coordinates
{
    SVSelectionBorder *border = [self newSelectionBorder];
    
    NSRect result = [border drawingRectForGraphicBounds:[[self HTMLElement] boundingBox]];
    [border release];
    
    return result;
}

- (SVSelectionBorder *)newSelectionBorder;
{
    SVSelectionBorder *border = [[SVSelectionBorder alloc] init];
    [border setMinSize:NSMakeSize(5.0f, 5.0f)];
    
    return border;
}

#pragma mark Debugging

- (NSString *)descriptionWithIndent:(NSUInteger)level
{
    // Indent
    NSString *indent = [@"" stringByPaddingToLength:level withString:@"\t" startingAtIndex:0];
    
    // Standard
    NSString *result = [indent stringByAppendingString:[super description]];
                        
    NSString *blurb = [self blurb];
    if (blurb) result = [result stringByAppendingFormat:@" %@", blurb];
    
    // Children
    for (WEKWebEditorItem *anItem in [self childWebEditorItems])
    {
        result = [result stringByAppendingFormat:
                  @"\n%@",
                  [anItem descriptionWithIndent:(level + 1)]];
    }
    
    return result;
}

- (NSString *)description
{
    return [self descriptionWithIndent:0];
}

- (NSString *)blurb
{
    return nil;
}

@end


#pragma mark -


@implementation SVWebEditorItemEnumerator

- (id)initWithItem:(WEKWebEditorItem *)item;
{
    [self init];
    
    // For now, the easy thing is to cheat and gather everything up into a single array immediately, and enumerate that
    NSMutableArray *items = [[NSMutableArray alloc] init];
    [item populateDescendants:items];
    
    _iterator = [[items objectEnumerator] retain];
    [items release];
    
    return self;
}

- (void)dealloc
{
    [_iterator release];
    
    [super dealloc];
}

- (id)nextObject { return [_iterator nextObject]; }

- (NSArray *)allObjects { return [_iterator allObjects]; }

@end

