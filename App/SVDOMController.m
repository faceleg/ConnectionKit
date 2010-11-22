//
//  SVDOMController.m
//  Sandvox
//
//  Created by Mike on 13/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVDOMController.h"

#import "SVSidebarDOMController.h"
#import "SVSizeBindingDOMController.h"
#import "SVTextDOMController.h"
#import "SVWebEditorViewController.h"

#import "DOMNode+Karelia.h"


#define sWebViewDependenciesObservationContext @"SVWebViewDependenciesObservationContext"


@implementation SVDOMController

#pragma mark Init & Dealloc

- (id)init;
{
    [super init];
    
    _dependencies = [[NSMutableSet alloc] init];
    [self startObservingDependencies];
    
    return self;
}

- (id)initWithRepresentedObject:(id <SVDOMControllerRepresentedObject>)content;
{
    // Use the object's own ID if it has one. Otherwise make up our own
    if (self = [self init])
    {
        NSString *idName = [content elementIdName];
		if (idName) [self setElementIdName:idName];
		
    	[self setRepresentedObject:content];
    }
    return self;
}

- (SVSizeBindingDOMController *)newSizeBindingControllerWithRepresentedObject:(id)object;
{
    return [[SVSizeBindingDOMController alloc] initWithRepresentedObject:object];
}

- (void)dealloc
{
    [self removeAllDependencies];
    [_dependencies release];
    
    [_updateSelectors release];
    [_elementID release];
    [_context release];
    
    [_dragTypes release];
    
    [super dealloc];
}

#pragma mark Hierarchy

- (WEKWebEditorItem *)itemForDOMNode:(DOMNode *)node;
{
    for (WEKWebEditorItem *anItem in [self childWebEditorItems])
    {
        if ([anItem HTMLElement] == node) return anItem;
    }
    
    return nil;
}

#pragma mark Content

- (void)createHTMLElement
{
    // Gather the HTML
    NSMutableString *htmlString = [[NSMutableString alloc] init];
    
    SVWebEditorHTMLContext *context = [[[SVWebEditorHTMLContext class] alloc]
                                       initWithOutputWriter:htmlString inheritFromContext:[self HTMLContext]];
    
    [[self representedObject] writeHTML:context];
    
    
    // Create DOM objects from HTML
    DOMDocumentFragment *fragment = [[self HTMLDocument]
                                     createDocumentFragmentWithMarkupString:htmlString
                                     baseURL:[[self HTMLContext] baseURL]];
    [htmlString release];
    
    DOMHTMLElement *element = [fragment firstChildOfClass:[DOMHTMLElement class]];  OBASSERT(element);
    [self setHTMLElement:element];
    
    
    // Insert controllers
    for (WEKWebEditorItem *aController in [[context rootDOMController] childWebEditorItems])
    {
        [self addChildWebEditorItem:aController];
    }
    [context release];
}

- (void)loadHTMLElementFromDocument:(DOMDocument *)document;
{
    DOMHTMLElement *element = (DOMHTMLElement *)[document getElementById:[self elementIdName]];
    
    if (![[self representedObject] shouldPublishEditingElementID])
    {
        // Ideally, as we're clearing out value from the DOM, should also stop referencing it ourselves. If an update occurs, the id should be regenerated. This isn't quite working yet though.
        //[self setElementIdName:nil];
        [element setIdName:nil];
    }
    
    [self setHTMLElement:element];
}

@synthesize elementIdName = _elementID;

@synthesize HTMLContext = _context;

#pragma mark Updating

- (BOOL)canUpdate;
{
    return [self respondsToSelector:@selector(update)];
}

- (void)didUpdateWithSelector:(SEL)selector;
{
    [_updateSelectors removeObject:NSStringFromSelector(selector)];
    
    
    // Turn dependencies back on. #94602
    if (![self needsUpdate]) [self startObservingDependencies];
    
    
    SVWebEditorViewController *controller = [self webEditorViewController];
    OBASSERT(controller || ![self webEditor]);
    [controller performSelector:@selector(didUpdate)];
    
    // Force a redraw if affected. #82536
    if ([self isSelected] && ![[self webEditor] inLiveGraphicResize])
    {
        [[[self HTMLElement] documentView] setNeedsDisplay:YES];
    }
}

- (void)updateToReflectSelection;
{
    [super updateToReflectSelection];
    
    // Turn off editing for enclosing text temporarily. #75840
    // It's a little hacky, but works!
    SVTextDOMController *textController = [[self parentWebEditorItem] textDOMController];
    DOMHTMLElement *element = [textController textHTMLElement];
    
    if ([self isEditing])
    {
        [[element style] setProperty:@"-webkit-user-modify" value:@"read-only" priority:@"!important"];
    }
    else
    {
        [[element style] removeProperty:@"-webkit-user-modify"];
    }
}

#pragma mark Marking for Update

- (BOOL)needsUpdate; { return [_updateSelectors count]; }

- (BOOL)needsToUpdateWithSelector:(SEL)selector;    // has a specific selector been registered?
{
    return [_updateSelectors containsObject:NSStringFromSelector(selector)];
}

- (void)setNeedsUpdate;
{
    if ([self canUpdate])
    {
        [self setNeedsUpdateWithSelector:@selector(update)];
    
        // Once we're marked for update, no point continuing to observe
        if ([self needsUpdate])
        {
            [self stopObservingDependencies];
        }
    }
    else
    {
        [super setNeedsUpdate];
    }
}

- (void)setNeedsUpdateWithSelector:(SEL)selector;   // selector will be called at next cycle
{
    OBPRECONDITION(selector);
    
    // Ignore such preposterous claims if not even attached to an element yet
    if (![self HTMLElement] && [self elementIdName])
    {
        // But this could be because the Web Editor is mid reload. If so, do a full update (nasty, but best option available right now I think). #93345
        SVWebEditorViewController *viewController = [self webEditorViewController];
        [viewController setNeedsUpdate];
        return;
    }
    
    
    // Try to get hold of the controller in charge of update coalescing
	SVWebEditorViewController *controller = [self webEditorViewController];
    if ([controller respondsToSelector:@selector(scheduleUpdate)])
    {
        NSString *selectorString = NSStringFromSelector(selector);
        if (_updateSelectors)
        {
            [_updateSelectors addObject:selectorString];
        }
        else
        {
            _updateSelectors = [[NSMutableSet alloc] initWithObjects:selectorString, nil];
        }
        
        [controller performSelector:@selector(scheduleUpdate)];
    }
}

- (void)updateIfNeeded; // recurses down the tree
{
    // Nil out ivar so it can be reused immediately
    // Also in case the update is async and hasn't finished yet
    NSSet *selectorStrings = _updateSelectors; _updateSelectors = nil;
    
    for (NSString *aSelectorString in selectorStrings)
    {
        SVWebEditorViewController *controller = [self webEditorViewController];
        OBASSERT(controller);
        [controller performSelector:@selector(willUpdate)];
        
        [self performSelector:NSSelectorFromString(aSelectorString)];
    }
    [selectorStrings release];
    
    
    [super updateIfNeeded];
}

#pragma mark Dependencies

- (NSSet *)dependencies { return [[_dependencies copy] autorelease]; }

- (void)beginObservingDependency:(KSObjectKeyPathPair *)pair;
{
    [[pair object] addObserver:self
                    forKeyPath:[pair keyPath]
                       options:NSKeyValueObservingOptionPrior
                       context:sWebViewDependenciesObservationContext];
}

- (void)beginObservingDependencies;
{
    for (KSObjectKeyPathPair *aDependency in [self dependencies])
    {
        [self beginObservingDependency:aDependency];
    }
    _isObservingDependencies = YES;
}

- (void)endObservingDependencies;
{
    for (KSObjectKeyPathPair *aDependency in [self dependencies])
    {
        [[aDependency object] removeObserver:self forKeyPath:[aDependency keyPath]];
    }
    _isObservingDependencies = NO;
}

- (void)addDependency:(KSObjectKeyPathPair *)pair;
{
    OBASSERT(_dependencies);
    
    // Ignore parser properties
    if (![[pair object] isKindOfClass:[SVTemplateParser class]])
    {
        if (![_dependencies containsObject:pair])
        {
            [_dependencies addObject:pair];
            if ([self isObservingDependencies]) [self beginObservingDependency:pair];
        }
    }
}

- (void)removeAllDependencies;
{
    if ([self isObservingDependencies]) [self endObservingDependencies];
    [_dependencies removeAllObjects];
}

- (void)startObservingDependencies;
{
    if (![self isObservingDependencies]) [self beginObservingDependencies];
    
    [super startObservingDependencies]; // recurse
}

- (void)stopObservingDependencies;
{
    if ([self isObservingDependencies]) [self endObservingDependencies];
    
    [super stopObservingDependencies]; // recurse
}

- (BOOL)isObservingDependencies; { return _isObservingDependencies; }

#pragma mark Sidebar

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal;
{
    NSDragOperation result = [super draggingSourceOperationMaskForLocal:isLocal];
    
    if (isLocal && (!(result & NSDragOperationMove) || !(result & NSDragOperationGeneric)))
    {
        if ([self sidebarDOMController] || [self textDOMController])
        {
            result = result | NSDragOperationMove | NSDragOperationGeneric;
        }
    }
    
    return result;
}

#pragma mark Editing

- (void)delete;
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
}

#pragma mark Summary

- (NSArray *)contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems;
{
    // Pass off to a better target if there is one
    DOMNode *node = [element objectForKey:WebElementDOMNodeKey];
    WEKWebEditorItem *item = [self hitTestDOMNode:node];
    if (item != self)
    {
        return [item contextMenuItemsForElement:element defaultMenuItems:defaultMenuItems];
    }
    
    return [super contextMenuItemsForElement:element defaultMenuItems:defaultMenuItems];
}

#pragma mark Resizing

- (NSSize)minSize; { return NSMakeSize(200.0f, 16.0f); }

- (CGFloat)maxWidth;
{
    // Whew, what a lot of questions! Now, should this drag be disallowed on account of making the DOM element bigger than its container? #84958
    DOMNode *parent = [[self HTMLElement] parentNode];
    DOMCSSStyleDeclaration *style = [[[self HTMLElement] ownerDocument] 
                                     getComputedStyle:(DOMElement *)parent
                                     pseudoElement:@""];
    
    CGFloat result = [[style width] floatValue];
    
    
    // Bring back down to take into account margin/border/padding. #94079
    DOMElement *graphic = [self graphicDOMElement];
    if (!graphic) graphic = [self HTMLElement];
        
    style = [[[self HTMLElement] ownerDocument] getComputedStyle:graphic
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
    if ([[style getPropertyValue:@"float"] isEqualToString:@"right"] ||
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
        DOMCSSStyleDeclaration *style = [(DOMElement *)aRule style];  // not published in our version of WebKit
        
        if ([[style marginLeft] isEqualToString:@"auto"])
        {
            result = kCALayerLeftEdge;
            if ([[style marginRight] isEqualToString:@"auto"]) result = result | kCALayerRightEdge;
            return result;
        }
    }
    
    
    // Finish up
    return result;
}

- (unsigned int)resizingMask
{
    return [[self enclosingGraphicDOMController] resizingMask];
}

- (void)resizeToSize:(NSSize)size byMovingHandle:(SVGraphicHandle)handle;
{
    // The DOM has been updated, which may have caused layout. So position the mouse cursor to match
    /*point = [self locationOfHandle:handle];
     NSView *view = [[self HTMLElement] documentView];
     NSPoint basePoint = [[view window] convertBaseToScreen:[view convertPoint:point toView:nil]];
     CGWarpMouseCursorPosition(NSPointToCGPoint(basePoint));
     */
}

- (SVGraphicHandle)resizeByMovingHandle:(SVGraphicHandle)handle toPoint:(NSPoint)point;
{
    // Start with the original bounds.
    NSRect bounds = [[self selectableDOMElement] boundingBox];
    
    // Is the user changing the width of the graphic?
    if (handle == kSVGraphicUpperLeftHandle ||
        handle == kSVGraphicMiddleLeftHandle ||
        handle == kSVGraphicLowerLeftHandle)
    {
        // Change the left edge of the graphic.
        bounds.size.width = NSMaxX(bounds) - point.x;
        bounds.origin.x = point.x;
    }
    else if (handle == kSVGraphicUpperRightHandle ||
             handle == kSVGraphicMiddleRightHandle ||
             handle == kSVGraphicLowerRightHandle)
    {
        // Change the right edge of the graphic.
        bounds.size.width = point.x - bounds.origin.x;
    }
    
    // Did the user actually flip the graphic over?   OR RESIZE TO TOO SMALL?
    NSSize minSize = [self minSize];
    if (bounds.size.width <= minSize.width) bounds.size.width = minSize.width;
    
    
    
    // Is the user changing the height of the graphic?
    if (handle == kSVGraphicUpperLeftHandle ||
        handle == kSVGraphicUpperMiddleHandle ||
        handle == kSVGraphicUpperRightHandle) 
    {
        // Change the top edge of the graphic.
        bounds.size.height = NSMaxY(bounds) - point.y;
        bounds.origin.y = point.y;
    }
    else if (handle == kSVGraphicLowerLeftHandle ||
             handle == kSVGraphicLowerMiddleHandle ||
             handle == kSVGraphicLowerRightHandle)
    {
        // Change the bottom edge of the graphic.
        bounds.size.height = point.y - bounds.origin.y;
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

- (NSSize)constrainSize:(NSSize)size handle:(SVGraphicHandle)handle snapToFit:(BOOL)snapToFit;
{
    if (snapToFit)
    {
        // Whew, what a lot of questions! Now, should this drag be disallowed on account of making the DOM element bigger than its container? #84958
        DOMNode *parent = [[self HTMLElement] parentNode];
        DOMCSSStyleDeclaration *style = [[[self HTMLElement] ownerDocument] 
                                         getComputedStyle:(DOMElement *)parent
                                         pseudoElement:@""];
        
        CGFloat maxWidth = [[style width] floatValue];
        if (size.width > maxWidth) size.width = maxWidth;
    }
    
    return size;
}

#pragma mark Moving

/*  Probably don't really want to move this item, but the graphic as a whole
 */

- (BOOL)moveToPosition:(CGPoint)position event:(NSEvent *)event;
{
    return [[self enclosingGraphicDOMController] moveToPosition:position event:event];
}

- (void)moveEnded;
{
    return [[self enclosingGraphicDOMController] moveEnded];
}

- (CGPoint)position;    // center point (for moving) in doc view coordinates
{
    return [[self enclosingGraphicDOMController] position];
}

#pragma mark Dragging

- (NSArray *)registeredDraggedTypes; { return _dragTypes; }

- (void)registerForDraggedTypes:(NSArray *)newTypes;
{
    NSArray *registeredTypes = [self registeredDraggedTypes];
    if (registeredTypes)
    {
        // Add in any of newTypes that haven't already been registered
        for (NSString *aType in newTypes)
        {
            if (![registeredTypes containsObject:aType])
            {
                NSArray *result = [registeredTypes arrayByAddingObject:aType];
                [_dragTypes release]; _dragTypes = [result copy];
                
                registeredTypes = [self registeredDraggedTypes];
            }
        }
    }
    else
    {
        // TODO: Check the values are unique
        _dragTypes = [newTypes copy];
    }
}

- (void)unregisterDraggedTypes;
{
    [_dragTypes release]; _dragTypes = nil;
}

#pragma mark Drawing

- (SVSelectionBorder *)newSelectionBorder;
{
    SVSelectionBorder *result = [super newSelectionBorder];
    
    // Hide border on <OBJECT> tags etc.
    DOMElement *selectionElement = [self selectableDOMElement];
    NSString *tagName = [selectionElement tagName];
    
    if ([tagName isEqualToString:@"IMG"] ||
        [tagName isEqualToString:@"AUDIO"] ||
        [tagName isEqualToString:@"VIDEO"] ||
        [tagName isEqualToString:@"OBJECT"] ||
        [tagName isEqualToString:@"IFRAME"])
    {
        [result setBorderColor:nil];
    }
    
    // Turn off handles while moving
    if ([[self enclosingGraphicDOMController] hasRelativePosition]) [result setEditing:YES];
    
    return result;
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == sWebViewDependenciesObservationContext)
    {
        [self setNeedsUpdate];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end


#pragma mark -


@implementation SVContentObject (SVDOMController)

- (SVDOMController *)newDOMController;
{
    return [[SVDOMController alloc] initWithRepresentedObject:self];
}

- (NSString *)elementIdName; { return nil; }

- (BOOL)shouldPublishEditingElementID; { return NO; }

@end


#pragma mark -


@implementation WEKWebEditorItem (SVDOMController)

#pragma mark Content

- (void)loadHTMLElementFromDocument:(DOMDocument *)document; { }

#pragma mark Updating

- (SVWebEditorViewController *)webEditorViewController;
{
    return [[self parentWebEditorItem] webEditorViewController];
}

- (void)setNeedsUpdate;
{
    [[self parentWebEditorItem] setNeedsUpdate];
}

- (void)updateIfNeeded; // recurses down the tree
{
    // The update may well have meant no children need updating any more. If so, no biggie as this recursion should do nothing
    [[self childWebEditorItems] makeObjectsPerformSelector:_cmd];
}

- (SVWebEditorHTMLContext *)HTMLContext { return nil; }

#pragma mark Dependencies

- (void)startObservingDependencies;
{
    [[self childWebEditorItems] makeObjectsPerformSelector:_cmd];
}

- (void)stopObservingDependencies;
{
    [[self childWebEditorItems] makeObjectsPerformSelector:_cmd];
}

#pragma mark Moving in Article

- (void)moveItemUp:(SVDOMController *)item;
{
    // By default have no idea how to move, so get parent to do it
    [[self parentWebEditorItem] moveItemUp:self];
}

- (void)moveItemDown:(SVDOMController *)item;
{
    // By default have no idea how to move, so get parent to do it
    [[self parentWebEditorItem] moveItemDown:self];
}

- (void)moveUp; { [[self parentWebEditorItem] moveItemUp:self]; }

- (void)moveDown; { [[self parentWebEditorItem] moveItemDown:self]; }

#pragma mark Drag & Drop

- (NSArray *)registeredDraggedTypes; { return nil; }

@end


#pragma mark -


@implementation WEKDOMController (SVDOMController)

#pragma mark Moving

- (void)exchangeWithPreviousDOMNode;     // swaps with previous sibling node
{
    DOMElement *element = [self HTMLElement];
    
    [[element parentNode] insertBefore:[element previousSibling]
                              refChild:[element nextSibling]];
}

- (void)exchangeWithNextDOMNode;   // swaps with next sibling node
{
    DOMElement *element = [self HTMLElement];
    
    [[element parentNode] insertBefore:[element nextSibling]
                              refChild:element];
}

@end

