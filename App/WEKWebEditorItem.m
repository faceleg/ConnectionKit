//
//  WEKWebEditorItem.m
//  Sandvox
//
//  Created by Mike on 24/09/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "WEKWebEditorItem.h"
#import "WEKWebEditorView.h"

#import "NSColor+Karelia.h"
#import "NSEvent+Karelia.h"
#import "NSString+Karelia.h"
#import "DOMNode+Karelia.h"

#import <Carbon/Carbon.h>


@interface SVWebEditorItemEnumerator : NSEnumerator
{
    NSEnumerator    *_iterator;
}

- (id)initWithItem:(WEKWebEditorItem *)item;

@end


#pragma mark -



@implementation WEKWebEditorItem

#pragma mark Lifecycle

+ (void)initialize;
{
    [self exposeBinding:NSWidthBinding];
    [self exposeBinding:@"height"];
    [self exposeBinding:@"aspectRatio"];
}

- (void)dealloc
{
    [self unbind:NSWidthBinding];
    [self unbind:@"height"];
    [self unbind:@"aspectRatio"];
        
    [self setChildWebEditorItems:nil];
    
    [_width release];
    [_height release];
    
    [super dealloc];
}

#pragma mark DOM

- (void)setHTMLElement:(DOMHTMLElement *)element;
{
    [super setHTMLElement:element];
    
    NSNumber *width = nil;
    NSString *widthString = [element getAttribute:@"width"];
    if ([widthString length]) width = [NSNumber numberWithInteger:[widthString integerValue]];
    [_width release]; _width = [width copy];
    
    NSNumber *height = nil;
    NSString *heightString = [element getAttribute:@"height"];
    if ([heightString length]) height = [NSNumber numberWithInteger:[heightString integerValue]];
    [_height release]; _height = [height copy];
}

- (void)setAncestorNode:(DOMNode *)node recursive:(BOOL)recurse;
{
    [self setAncestorNode:node];
    
    if (recurse)
    {
        for (WEKWebEditorItem *anItem in [self childWebEditorItems])
        {
            [anItem setAncestorNode:node recursive:recurse];
        }
    }
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
    [item retain];  // remove from parent might dealloc it
    if (parent) [item removeFromParentWebEditorItem];
    
    
    // Add
    [item itemWillMoveToParentWebEditorItem:self];
    
    NSArray *children = [[self childWebEditorItems] arrayByAddingObject:item];
    if (!children) children = [NSArray arrayWithObject:item];
    [_childControllers release]; _childControllers = [children copy];
    
    [item setParentWebEditorItem:self];
    
    [item itemDidMoveToParentWebEditorItem];
    [item release];
}

- (void)replaceChildWebEditorItem:(WEKWebEditorItem *)oldItem withItems:(NSArray *)newItems
{
    // Remove from existing parent. Most items already have no parent so this will have no effect
    [newItems makeObjectsPerformSelector:@selector(removeFromParentWebEditorItem)];
    
    
    
    NSMutableArray *children = [[self childWebEditorItems] mutableCopy];
    NSUInteger index = [children indexOfObject:oldItem];
    
    
    // Start swap
    [oldItem retain];   // will possibly be deallocated by the replacement
    [oldItem itemWillMoveToParentWebEditorItem:nil];
    [oldItem setParentWebEditorItem:nil];
    [children replaceObjectsInRange:NSMakeRange(index, 1) withObjectsFromArray:newItems];
    
    // Alert new
    [newItems makeObjectsPerformSelector:@selector(itemWillMoveToParentWebEditorItem:)
                              withObject:self];
    
    // Finish the swap
    [_childControllers release]; _childControllers = children;
    [oldItem itemDidMoveToParentWebEditorItem];
    [oldItem release];
    
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
    [children removeObjectIdenticalTo:self];
    
    OBASSERT(parent);
    [parent->_childControllers release]; parent->_childControllers = children;
    // parent has taken ownership of children array so don't release it
    
    
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
    
    [self itemWillMoveToWebEditor:[newParentItem webEditor]];
}

- (void)itemWillMoveToWebEditor:(WEKWebEditorView *)newWebEditor;
{
    [[self childWebEditorItems] makeObjectsPerformSelector:_cmd withObject:newWebEditor];
}

- (void)itemDidMoveToParentWebEditorItem;
{
    [self itemDidMoveToWebEditor];
}

- (void)itemDidMoveToWebEditor;
{
    [[self childWebEditorItems] makeObjectsPerformSelector:_cmd];
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

@synthesize selectable = _selectable;

- (DOMRange *)selectableDOMRange;
{
    if ([self shouldTrySelectingInline])
    {
        DOMElement *element = [self HTMLElement];
        DOMRange *result = [[element ownerDocument] createRange];
        [result selectNode:element];
        return result;
    }
    else
    {
        return nil;
    }
}

- (BOOL)shouldTrySelectingInline;
{
    // Whether selecting the element should be inline (set the WebView's selection) or not (no WebView selection)
    
    BOOL result = NO;
    
    if ([self isSelectable])
    {
        DOMHTMLElement *element = [self HTMLElement];
        
        result = ([[element tagName] isEqualToString:@"IMG"] &&
                  ![[[element className] componentsSeparatedByWhitespace] containsObject:@"graphic"] &&
                  [element isContentEditable]);
    }
    
    return result;
}

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
    BOOL isVisible = [element ks_isDescendantOfNode:[element ownerDocument]];
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

- (void)mouseDown:(NSEvent *)theEvent;
{
    // Non-selectable items have no interest in such events
    if (![self isSelectable]) return [super mouseDown:theEvent];
    if ([theEvent type] != NSLeftMouseDown) return [super mouseDown:theEvent];
    
    
    WEKWebEditorView *webEditor = [self webEditor];
    
    // If mousing down on an image, pass the event through
    if ([self allowsDirectAccessToWebViewWhenSelected])
    {
        // Must do before changing selection so that WebView becomes first responder
        // Post the event as if in the past so that a drag can begin immediately. #109381
        [super mouseDown:[theEvent ks_eventWithTimestamp:0]];
        
        [webEditor selectItem:self event:theEvent];
    }
    else
    {
        [webEditor selectItem:self event:theEvent];
        
        // If the item is non-inline, simulate -acceptsFirstResponder by making self the first responder
        if (![self shouldTrySelectingInline] || ![[self HTMLElement] isContentEditable])
        {
            [[webEditor window] makeFirstResponder:webEditor];
        }
    }
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
    if (result)
    {
        // Only search children, for a closer match
        for (WEKWebEditorItem *anItem in [self childWebEditorItems])
        {
            if ([anItem representedObject] == object)
            {
                result = [anItem hitTestRepresentedObject:object];
                break;
            }
        }
    }
    else
    {
        // Keep recursing
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
    if ([self parentWebEditorItem])
    {
        defaultMenuItems = [[self parentWebEditorItem] contextMenuItemsForElement:element
                                                                 defaultMenuItems:defaultMenuItems];
    }
    return defaultMenuItems;
}

#pragma mark Moving

- (BOOL)moveToPosition:(CGPoint)position event:(NSEvent *)event;
{
    return NO;
}

- (CGPoint)position;    // center point (for moving) in doc view coordinates
{
    NSRect rect = [self selectionFrame];
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

#pragma mark Metrics

@synthesize width = _width;
- (void)setWidth:(NSNumber *)width;
{
    width = [width copy];
    [_width release]; _width = width;
    
    [self updateWidth];
}

@synthesize height = _height;
- (void)setHeight:(NSNumber *)height;
{
    height = [height copy];
    [_height release]; _height = height;
    
    [self updateHeight];
}

- (void)updateWidth;
{
    DOMHTMLElement *element = [self HTMLElement];
    if ([element respondsToSelector:@selector(setWidth:)])
    {
        [element setAttribute:@"width" value:[[self width] description]];
    }
    else
    {
        [[element style] setWidth:[[[self width] description] stringByAppendingString:@"px"]];
    }
}

- (void)updateHeight;
{
    DOMHTMLElement *element = [self HTMLElement];
    if ([element respondsToSelector:@selector(setHeight:)])
    {
        [element setAttribute:@"height" value:[[self height] description]];
    }
    else
    {
        [[element style] setHeight:[[[self height] description] stringByAppendingString:@"px"]];
    }
}

#pragma mark Resizing

@synthesize horizontallyResizable = _horizontallyResizable;
@synthesize verticallyResizable = _verticallyResizable;

@synthesize aspectRatio = _aspectRatio;
@synthesize sizeDelta = _delta;

- (NSSize)minSize; { return NSMakeSize(200.0f, 16.0f); }

- (CGFloat)maxWidth;
{
    return [[self parentWebEditorItem] maxWidthForChild:self];
}

- (CGFloat)maxWidthForChild:(WEKWebEditorItem *)aChild;
{
    // Whew, what a lot of questions! Now, should this drag be disallowed on account of making the DOM element bigger than its container? #84958
    DOMNode *parent = [[aChild HTMLElement] parentNode];
    DOMCSSStyleDeclaration *style = [[[aChild HTMLElement] ownerDocument] 
                                     getComputedStyle:(DOMElement *)parent
                                     pseudoElement:@""];
    
    CGFloat result = [[style width] floatValue];
    
    
    // Bring back down to take into account margin/border/padding. #94079
    DOMElement *graphic = [aChild HTMLElement];
    
    style = [[[aChild HTMLElement] ownerDocument] getComputedStyle:graphic
                                                   pseudoElement:@""];
    
    result -= ([[style borderLeftWidth] integerValue] + [[style paddingLeft] integerValue] +
               [[style borderRightWidth] integerValue] + [[style paddingRight] integerValue]);
    
    
    return result;
}

- (unsigned int)resizingMaskForDOMElement:(DOMElement *)element;
{
    unsigned int result = kCALayerRightEdge; // default to adjustment from right-hand edge
    
    
    DOMCSSStyleDeclaration *style = [[element ownerDocument] getComputedStyle:element pseudoElement:@""];
    
    
    // Is the aligned/floated left/center/right?
    if ([[style getPropertyValue:@"float"] isEqualToString:@"right"] ||  // -cssFloat returns empty string for some reason
        [[style textAlign] isEqualToString:@"right"])
    {
        result = kCALayerLeftEdge;
        return result;
    }
    else if ([[style textAlign] isEqualToString:@"center"])
    {
        result = result | kCALayerLeftEdge;
        return result;
    }
    
    
    // Couldn't tell from float/alignment. For inline elements, maybe parent is more helpful?
    if ([[style display] isEqualToString:@"inline"])
    {
        return [self resizingMaskForDOMElement:(DOMElement *)[element parentNode]];
    }
    
    
    // Fall back to guessing from block margins
    DOMCSSRuleList *rules = [[element ownerDocument] getMatchedCSSRules:element pseudoElement:@""];
    
    for (int i = 0; i < [rules length]; i++)
    {
        DOMCSSRule *aRule = [rules item:i];
        DOMCSSStyleDeclaration *ruleStyle = [(DOMElement *)aRule style];  // not published in our version of WebKit
        
        if ([[ruleStyle marginLeft] isEqualToString:@"auto"])
        {
            result = kCALayerLeftEdge;
            if ([[ruleStyle marginRight] isEqualToString:@"auto"]) result = result | kCALayerRightEdge;
            return result;
        }
    }
    
    
    // Finish up
    return result;
}

- (unsigned int)resizingMask;
{
    unsigned int result = 0;
    if ([self isHorizontallyResizable])
    {
        result = [self resizingMaskForDOMElement:[self HTMLElement]];
    }
    if ([self isVerticallyResizable])
    {
        result = result | kCALayerBottomEdge;
    }
    
    return result;
}

- (SVGraphicHandle)resizeUsingHandle:(SVGraphicHandle)handle event:(NSEvent *)event;
{
    NSPoint point = NSZeroPoint;
    
    BOOL resizeInline = [self shouldResizeInline];
    if (!resizeInline)
    {
        NSView *docView = [[self HTMLElement] documentView];
        point = [docView convertPoint:[event locationInWindow] fromView:nil];
    }
    
    
    
    // Start with the original bounds.
    NSRect bounds = [self selectionFrame];
    
    // Is the user changing the width of the graphic?
    if (handle == kSVGraphicUpperLeftHandle ||
        handle == kSVGraphicMiddleLeftHandle ||
        handle == kSVGraphicLowerLeftHandle)
    {
        // Change the left edge of the graphic
        if (resizeInline)
        {
            bounds.size.width -= [event deltaX];
            bounds.origin.x -= [event deltaX];
        }
        else
        {
            bounds.size.width = NSMaxX(bounds) - point.x;
            bounds.origin.x = point.x;
        }
    }
    else if (handle == kSVGraphicUpperRightHandle ||
             handle == kSVGraphicMiddleRightHandle ||
             handle == kSVGraphicLowerRightHandle)
    {
        // Change the right edge of the graphic
        if (resizeInline)
        {
            bounds.size.width += [event deltaX];
        }
        else
        {
            bounds.size.width = point.x - bounds.origin.x;
        }
    }
    
    // Did the user actually flip the graphic over?   OR RESIZE TO TOO SMALL?
    NSSize minSize = [self minSize];
    if (bounds.size.width <= minSize.width) bounds.size.width = minSize.width;
    
    
    
    // Is the user changing the height of the graphic?
    if (handle == kSVGraphicUpperLeftHandle ||
        handle == kSVGraphicUpperMiddleHandle ||
        handle == kSVGraphicUpperRightHandle) 
    {
        // Change the top edge of the graphic
        if (resizeInline)
        {
            bounds.size.height -= [event deltaY];
            bounds.origin.y -= [event deltaY];
        }
        else
        {
            bounds.size.height = NSMaxY(bounds) - point.y;
            bounds.origin.y = point.y;
        }
    }
    else if (handle == kSVGraphicLowerLeftHandle ||
             handle == kSVGraphicLowerMiddleHandle ||
             handle == kSVGraphicLowerRightHandle)
    {
        // Change the bottom edge of the graphic
        if (resizeInline)
        {
            bounds.size.height += [event deltaY];
        }
        else
        {
            bounds.size.height = point.y - bounds.origin.y;
        }
    }
    
    // Did the user actually flip the graphic upside down?   OR RESIZE TO TOO SMALL?
    if (bounds.size.height<=minSize.height) bounds.size.height = minSize.height;
    
    
    // Apply constraints. Snap to guides UNLESS the command key is held down. Why not use current NSEvent? - Mike
    NSSize size = [self constrainSize:bounds.size
                               handle:handle
                            snapToFit:((GetCurrentKeyModifiers() & cmdKey) == 0)];
    
    
    // Finally, we can go ahead and resize
    [self resizeToSize:size byMovingHandle:handle];
    
    
    return handle;
}

- (void)resizeToSize:(NSSize)size byMovingHandle:(SVGraphicHandle)handle;
{
    // Apply the change
    NSNumber *width = (size.width > 0 ? [NSNumber numberWithInt:size.width] : nil);
    
    
    NSDictionary *info = [self infoForBinding:NSWidthBinding];
    if (info)
    {
        [[info objectForKey:NSObservedObjectKey] setValue:width
                                               forKeyPath:[info objectForKey:NSObservedKeyPathKey]];
    }
    else
    {
        [self setWidth:width];
    }
    
    
    // Check height should be adjusted, otherwise auto height can get accidentally locked in
    if ((handle != kSVGraphicMiddleLeftHandle && handle != kSVGraphicMiddleRightHandle) ||
        ([self aspectRatio].width > 0 && [self aspectRatio].height > 0))
    {
        NSNumber *height = (size.height > 0 ? [NSNumber numberWithInt:size.height] : nil);
        info = [self infoForBinding:@"height"];
        if (info)
        {
            [[info objectForKey:NSObservedObjectKey] setValue:height
                                                   forKeyPath:[info objectForKey:NSObservedKeyPathKey]];
        }
        else
        {
            [self setHeight:height];
        }
    }
}

- (NSSize)constrainSize:(NSSize)size handle:(SVGraphicHandle)handle snapToFit:(BOOL)snapToFit;
{
    /*if (snapToFit)
    {
        // Whew, what a lot of questions! Now, should this drag be disallowed on account of making the DOM element bigger than its container? #84958
        DOMNode *parent = [[self HTMLElement] parentNode];
        DOMCSSStyleDeclaration *style = [[[self HTMLElement] ownerDocument] 
                                         getComputedStyle:(DOMElement *)parent
                                         pseudoElement:@""];
        
        CGFloat maxWidth = [[style width] floatValue];
        if (size.width > maxWidth) size.width = maxWidth;
    }
    
    return size;*/
    
    
    
    
    
    /*  This logic is almost identical to SVPlugInDOMController, although the code here can probably be pared down to deal only with width
     */
    
    
    // If constrained proportions, apply that
    NSSize ratio = [self aspectRatio];
    
    if (ratio.width > 0 && ratio.height > 0)
    {
        BOOL resizingWidth = (handle == kSVGraphicUpperLeftHandle ||
                              handle == kSVGraphicMiddleLeftHandle ||
                              handle == kSVGraphicLowerLeftHandle ||
                              handle == kSVGraphicUpperRightHandle ||
                              handle == kSVGraphicMiddleRightHandle ||
                              handle == kSVGraphicLowerRightHandle);
        
        BOOL resizingHeight = (handle == kSVGraphicUpperLeftHandle ||
                               handle == kSVGraphicUpperMiddleHandle ||
                               handle == kSVGraphicUpperRightHandle ||
                               handle == kSVGraphicLowerLeftHandle ||
                               handle == kSVGraphicLowerMiddleHandle ||
                               handle == kSVGraphicLowerRightHandle);
        
        CGFloat ratioValue = (ratio.width / ratio.height);
        
        if (resizingWidth)
        {
            if (resizingHeight)
            {
                // Go for the biggest size of the two possibilities
                if ((size.width / size.height) < ratioValue)
                {
                    size.width = size.height * ratioValue;
                }
                else
                {
                    size.height = size.width / ratioValue;
                }
            }
            else
            {
                size.height = size.width / ratioValue;
            }
        }
        else if (resizingHeight)
        {
            size.width = size.height * ratioValue;
        }
    }
    
    
    
    if (snapToFit)
    {
        CGFloat maxWidth = [self maxWidth];
        if (size.width > maxWidth)
        {
            // Keep within max width
            // Switch over to auto-sized for simple graphics
            size.width = [self constrainToMaxWidth:maxWidth];
            if (ratio.width > 0 && ratio.height > 0) size.height = maxWidth / (ratio.width / ratio.height);
        }
    }
    
    
    return size;
}

- (CGFloat)constrainToMaxWidth:(CGFloat)maxWidth; { return maxWidth; }

- (BOOL)shouldResizeInline; // Default is NO. If YES, cursor will be locked to match the resize
{
    return NO;
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

- (NSRect)selectionFrame;
{
    NSRect result = NSZeroRect;
    
    if ([self isSelectable])
    {
        DOMHTMLElement *element = [self HTMLElement];
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
        NSRect outline = NSInsetRect([[self HTMLElement] boundingBox], -4.0f, -4.0f);
        result = NSUnionRect(result, outline);
    }
    else if ([self isSelected])
    {
        KSSelectionBorder *border = [self newSelectionBorder];
        NSRect outline = [border drawingRectForGraphicBounds:[self selectionFrame]];
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
        NSRect frameRect = [view convertRect:[self selectionFrame]
                                    fromView:[element documentView]];

		
		// Selection border and handles
		
        KSSelectionBorder *border = [self newSelectionBorder];
        
        // Don't need stroke if graphic provides its own
        DOMCSSStyleDeclaration *style = [[element ownerDocument] getComputedStyle:element pseudoElement:nil];
        if ([[style borderTopWidth] floatValue] > 0.0f &&
            [[style borderLeftWidth] floatValue] > 0.0f &&
            [[style borderRightWidth] floatValue] > 0.0f &&
            [[style borderBottomWidth] floatValue] > 0.0f)
        {
            [border setBorderColor:nil];
        }
        else
        {
            DOMRGBColor *color = [(DOMCSSPrimitiveValue *)[style getPropertyCSSValue:@"background-color"] getRGBColorValue];
            if ([[color color] alphaComponent] > 0.1) [border setBorderColor:nil];
        }
        
        
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

- (KSSelectionBorder *)newSelectionBorder;
{
    KSSelectionBorder *border = [[KSSelectionBorder alloc] init];
    [border setMinSize:NSMakeSize(5.0f, 5.0f)];
    
    BOOL editing = ([self isEditing] || [[self webEditor] inLiveGraphicResize]);
    [border setEditing:editing];
    
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

