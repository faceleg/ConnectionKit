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
- (void)setChildWebEditorItems:(NSArray *)newChildItems
{
    // Announce what will happen
    NSArray *oldChildren = _childControllers;
    
    [oldChildren makeObjectsPerformSelector:@selector(itemWillMoveToParentWebEditorItem:)
                                 withObject:nil];
    
    
    // Remove existing children
    [oldChildren makeObjectsPerformSelector:@selector(setParentWebEditorItem:)
                                 withObject:nil];
    _childControllers = nil;    // still hung on to as oldChildren
    
    
    // Let them know what happened
    [oldChildren makeObjectsPerformSelector:@selector(itemDidMoveToParentWebEditorItem)];
    [oldChildren release];
    
    
    // Announce what will happen to new children
    [newChildItems makeObjectsPerformSelector:@selector(itemWillMoveToParentWebEditorItem:)
                                   withObject:self];
    
    
    // Store new children
    _childControllers = [newChildItems copy];
    
    [_childControllers makeObjectsPerformSelector:@selector(setParentWebEditorItem:)
                                       withObject:self];
    
    
    // Let them know what happened
    [_childControllers makeObjectsPerformSelector:@selector(itemDidMoveToParentWebEditorItem)];
}

@synthesize parentWebEditorItem = _parentController;

- (void)setParentWebEditorItem:(WEKWebEditorItem *)item
{
    // When removing from the heirarchy, make sure we're no longer selected
    WEKWebEditorView *webEditorToRemoveFrom = (!item && [self isSelected] ? [self webEditor] : nil);
    
    _parentController = item;
    [self setNextResponder:item];
    
    [webEditorToRemoveFrom deselectItem:self];
    
    
    // Let delegate know
    WEKWebEditorView *webEditor = [self webEditor]; // should be nil when removing
    [[webEditor delegate] webEditor:webEditor didAddItem:self];
}

- (void)addChildWebEditorItem:(WEKWebEditorItem *)item;
{
    OBPRECONDITION(item);
    
    WEKWebEditorItem *parent = [item parentWebEditorItem];
    if (parent == self) return;   // nothing to do
    
    
    // Remove from existing parent
    if (parent) [item removeFromParentWebEditorItem];
    
    
    // Add
    [item itemWillMoveToParentWebEditorItem:self];
    
    NSArray *children = [[self childWebEditorItems] arrayByAddingObject:item];
    if (!children) children = [NSArray arrayWithObject:item];
    [_childControllers release]; _childControllers = [children copy];
    
    [item setParentWebEditorItem:self];
    
    [item itemDidMoveToParentWebEditorItem];
}

- (void)replaceChildWebEditorItem:(WEKWebEditorItem *)oldItem with:(WEKWebEditorItem *)newItem;
{
    NSMutableArray *children = [[self childWebEditorItems] mutableCopy];
    NSUInteger index = [children indexOfObject:oldItem];
    
    
    // Start swap
    [oldItem itemWillMoveToParentWebEditorItem:nil];
    [oldItem setParentWebEditorItem:nil];
    [children replaceObjectAtIndex:index withObject:newItem];
    
    // Alert new
    [newItem itemWillMoveToParentWebEditorItem:self];
    
    // Finish the swap
    [_childControllers release]; _childControllers = children;
    [oldItem itemDidMoveToParentWebEditorItem];
    
    // Alert new
    [newItem setParentWebEditorItem:self];
    [newItem itemDidMoveToParentWebEditorItem];
}

- (void)removeFromParentWebEditorItem;
{
    // Bail early if there's nothing to do
    WEKWebEditorItem *parent = [self parentWebEditorItem];
    if (!parent) return;
    
    
    // Remove
    [self itemWillMoveToParentWebEditorItem:nil];
    [self setParentWebEditorItem:nil];
    [self retain];  // need to stay alive for removal message
    
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
    
    [self itemDidMoveToParentWebEditorItem];
    [self release];
}

- (void)itemWillMoveToParentWebEditorItem:(WEKWebEditorItem *)newParentItem;
{
    WEKWebEditorView *webEditor = [self webEditor];
    [[webEditor delegate] webEditor:webEditor willRemoveItem:self];
}

- (void)itemDidMoveToParentWebEditorItem; { }

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

- (BOOL)isSelectable; { return [self selectableDOMElement] != nil; }

- (DOMElement *)selectableDOMElement; { return nil; }

- (void)updateToReflectSelection;
{
    if ([self isSelected])
    {
        [[[self selectableDOMElement] style] setProperty:@"outline"
                                                   value:@"1px rgba(0,127,255,0.5) solid"
                                                priority:@""];
    }
    else if ([self isEditing])
    {
        [[[self selectableDOMElement] style] setProperty:@"outline"
                                                   value:@"1px gray solid"
                                                priority:@""];
    }
    else
    {
        [[[self selectableDOMElement] style] removeProperty:@"outline"];
    }
}

@synthesize selected = _selected;
- (void)setSelected:(BOOL)selected
{
    // -setNeedsDisplay relies on -drawingRect being right. So depending on if selecting or deselecting, have to call it at the right time.
    if (selected)
    {
        _selected = selected;
        [self setNeedsDisplay];
    }
    else
    {
        [self setNeedsDisplay];
        _selected = selected;
    }
    
    DOMElement *element = [self HTMLElement];
    BOOL isVisible = [element isDescendantOfNode:[element ownerDocument]];
    if (!isVisible)
    {
        // Fallback to total refresh. #82192
        [[element documentView] setNeedsDisplay:YES];
    }
    
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
    
    DOMElement *myElement = [self HTMLElement];
    if (!myElement || [node ks_isDescendantOfElement:myElement])
    {
        // Search for a descendant
        for (WEKWebEditorItem *anItem in [self childWebEditorItems])
        {
            result = [anItem hitTestDOMNode:node];
            if (result) break;
        }
        
        // If no descendants claim it, node is ours
        if (!result && myElement) result = self;
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

- (SVGraphicHandle)resizeByMovingHandle:(SVGraphicHandle)handle toPoint:(NSPoint)point;
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

- (NSRect)rect;
{
    return [[self selectableDOMElement] boundingBox];
}

- (NSRect)drawingRect;  // expressed in our DOM node's document view's coordinates
{
    NSRect result = NSZeroRect; // by default, don't draw
    
    if ([self isSelected] || [self isEditing])
    {
        SVSelectionBorder *border = [self newSelectionBorder];
        result = [border drawingRectForGraphicBounds:[self rect]];
        [border release];
    }
    
    return result;
}

#pragma mark Display

- (void)setNeedsDisplay;    // shortcut to -[WEKWebEditorView setNeedsDisplayForItem:] 
{
    [[self webEditor] setNeedsDisplayForItem:self];
}

#pragma mark Drawing

- (void)drawRect:(NSRect)dirtyRect inView:(NSView *)view;
{
    if ([self isSelected])
    {
        // Draw if we're in the dirty rect (otherwise drawing can get pretty pricey)
        DOMElement *element = [self HTMLElement];
        NSRect frameRect = [view convertRect:[self rect]
                                    fromView:[element documentView]];

		
		// Selection border and handles
		
        SVSelectionBorder *border = [self newSelectionBorder];
        
        NSRect borderDrawingRect = [border drawingRectForGraphicBounds:frameRect];
        if ([view needsToDrawRect:borderDrawingRect])
        {
            [border setResizingMask:[self resizingMask]];
            [border setEditing:[[self webEditor] inLiveGraphicResize]];
            [border drawWithGraphicBounds:frameRect inView:view];
        }
        
        [border release];
    }
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

