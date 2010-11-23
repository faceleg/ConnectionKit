//
//  WEKWebEditorItem.m
//  Sandvox
//
//  Created by Mike on 24/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "WEKWebEditorItem.h"
#import "WEKWebEditorView.h"

#import "NSColor+Karelia.h"
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
    _parentController = item;
    [self setNextResponder:item];
    
    
    
    // Let delegate know
    WEKWebEditorView *webEditor = [self webEditor]; // should be nil when removing
    [[webEditor delegate] webEditor:webEditor didAddItem:self];
}

- (BOOL)isDescendantOfWebEditorItem:(WEKWebEditorItem *)anItem;
{
    WEKWebEditorItem *testItem = self;
    while (testItem)
    {
        if (testItem == anItem) return YES;
        testItem = [testItem parentWebEditorItem];
    }
    
    return NO;
}

- (void)addChildWebEditorItem:(WEKWebEditorItem *)item;
{
    OBPRECONDITION(item);
    OBPRECONDITION(item != self);
    
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

- (void)replaceChildWebEditorItem:(WEKWebEditorItem *)oldItem withItems:(NSArray *)newItems
{
    NSMutableArray *children = [[self childWebEditorItems] mutableCopy];
    NSUInteger index = [children indexOfObject:oldItem];
    
    
    // Start swap
    [oldItem itemWillMoveToParentWebEditorItem:nil];
    [oldItem setParentWebEditorItem:nil];
    [children replaceObjectsInRange:NSMakeRange(index, 1) withObjectsFromArray:newItems];
    
    // Alert new
    [newItems makeObjectsPerformSelector:@selector(itemWillMoveToParentWebEditorItem:)
                              withObject:self];
    
    // Finish the swap
    [_childControllers release]; _childControllers = children;
    [oldItem itemDidMoveToParentWebEditorItem];
    
    // Alert new
    [newItems makeObjectsPerformSelector:@selector(setParentWebEditorItem:) withObject:self];
    [newItems makeObjectsPerformSelector:@selector(itemDidMoveToParentWebEditorItem)];
}

- (void)replaceChildWebEditorItem:(WEKWebEditorItem *)oldItem with:(WEKWebEditorItem *)newItem;
{
    [self replaceChildWebEditorItem:oldItem 
                          withItems:[NSArray arrayWithObject:newItem]];
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
    if (!newParentItem)
    {
        WEKWebEditorView *webEditor = [self webEditor];
        [webEditor willRemoveItem:self];
    }
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

#pragma mark Siblings

- (WEKWebEditorItem *)previousWebEditorItem;
{
    WEKWebEditorItem *parent = [self parentWebEditorItem];
    NSArray *siblings = [parent childWebEditorItems];
    NSUInteger index = [siblings indexOfObjectIdenticalTo:self];
    if (index > 0)
    {
        return [siblings objectAtIndex:(index - 1)];
    }
    return nil;
}

- (WEKWebEditorItem *)nextWebEditorItem;
{
    WEKWebEditorItem *parent = [self parentWebEditorItem];
    NSArray *siblings = [parent childWebEditorItems];
    NSUInteger index = [siblings indexOfObjectIdenticalTo:self] + 1;
    if (index <= [siblings count])
    {
        return [siblings objectAtIndex:index];
    }
    return nil;    
}

#pragma mark Selection

- (BOOL)isSelectable; { return [self selectableDOMElement] != nil; }

- (DOMElement *)selectableDOMElement; { return nil; }

- (void)updateToReflectSelection;
{
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
    if (isEditing)
    {
        _editing = isEditing;
        [self setNeedsDisplay];
    }
    else
    {
        [self setNeedsDisplay];
        _editing = isEditing;
    }
    
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

- (NSMenu *)menuForEvent:(NSEvent *)theEvent;
{
    NSMenu *result = nil;
    
    // Ask WebView for menu if item wants it
    if ([self allowsDirectAccessToWebViewWhenSelected])
    {
        NSPoint location = [[self webEditor] convertPoint:[theEvent locationInWindow] fromView:nil];
        NSView *targetView = [[[self webEditor] webView] hitTest:location];
        result = [targetView menuForEvent:theEvent];
    }
    else
    {
        result = [[self parentWebEditorItem] menuForEvent:theEvent];
    }
    
    return result;
}

#pragma mark UI

- (NSArray *)contextMenuItemsForElement:(NSDictionary *)element
                       defaultMenuItems:(NSArray *)defaultMenuItems;
{
    return defaultMenuItems;
}

#pragma mark Moving

- (BOOL)moveToPosition:(CGPoint)position event:(NSEvent *)event;
{
    return NO;
}

- (CGPoint)position;    // center point (for moving) in doc view coordinates
{
    NSRect rect = [self rect];
    return CGPointMake(NSMidX(rect), NSMidY(rect));
}

- (void)moveEnded; { }

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
    NSRect result = NSZeroRect;
    
    DOMElement *element = [self selectableDOMElement];
    if (element)
    {
        result = [element boundingBox];
        
        // Take into account padding and border
        DOMCSSStyleDeclaration *style = [[element ownerDocument] getComputedStyle:element
                                                                    pseudoElement:nil];
        
        CGFloat padding = [[style paddingLeft] floatValue];
        result.origin.x += padding;
        result.size.width -= [[style paddingRight] floatValue] + padding;
        
        padding = [[style paddingTop] floatValue];
        result.origin.y += padding;
        result.size.height -= [[style paddingBottom] floatValue] + padding;
        
        padding = [[style borderLeftWidth] floatValue];
        result.origin.x += padding;
        result.size.width -= [[style borderRightWidth] floatValue] + padding;
        
        padding = [[style borderTopWidth] floatValue];
        result.origin.y += padding;
        result.size.height -= [[style borderBottomWidth] floatValue] + padding;
    }
    
    return result;
}

- (NSRect)drawingRect;  // expressed in our DOM node's document view's coordinates
{
    // By default, do no drawing of our own, only children
    NSRect result = NSZeroRect;
    for (WEKWebEditorItem *aChild in [self childWebEditorItems])
    {
        result = NSUnionRect(result, [aChild drawingRect]);
    }
    
    if ([self isEditing])
    {
        NSRect outline = NSInsetRect([[self selectableDOMElement] boundingBox], -4.0f, -4.0f);
        result = NSUnionRect(result, outline);
    }
    else if ([self isSelected])
    {
        SVSelectionBorder *border = [self newSelectionBorder];
        NSRect outline = [border drawingRectForGraphicBounds:[self rect]];
        [border release];
        
        result = NSUnionRect(result, outline);
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
    if ([self isSelected] || [self isEditing])
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
            [border drawWithGraphicBounds:frameRect inView:view];
        }
        
        [border release];
    }
    else if ([self isEditing])
    {
        [[NSColor aquaColor] set];
        NSFrameRectWithWidth([self drawingRect], 3.0f);
    }
}

- (void)displayRect:(NSRect)aRect inView:(NSView *)view;
{
    [self drawRect:aRect inView:view];
    
    for (WEKWebEditorItem *anItem in [self childWebEditorItems])
    {
        [anItem displayRect:aRect inView:view];
    }
}

- (SVSelectionBorder *)newSelectionBorder;
{
    SVSelectionBorder *border = [[SVSelectionBorder alloc] init];
    [border setMinSize:NSMakeSize(5.0f, 5.0f)];
    [border setEditing:([self isEditing] || [[self webEditor] inLiveGraphicResize])];
    
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

