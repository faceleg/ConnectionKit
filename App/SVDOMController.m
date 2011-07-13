//
//  SVDOMController.m
//  Sandvox
//
//  Created by Mike on 13/12/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVDOMController.h"

#import "SVSidebarDOMController.h"
#import "SVResizableDOMController.h"
#import "SVTextDOMController.h"
#import "SVWebEditorViewController.h"

#import "DOMNode+Karelia.h"


@implementation SVDOMController

#pragma mark Init & Dealloc

- (id)init;
{
    [super init];
    
    _dependenciesTracker = [[KSDependenciesTracker alloc] initWithObservingOptions:NSKeyValueObservingOptionPrior];
    [_dependenciesTracker stopObservingDependencies];   // little dance so that subclasses start...
    [_dependenciesTracker setDelegate:self];
    [self startObservingDependencies];                  // ...observing extra dependencies
    
    return self;
}

- (id)initWithRepresentedObject:(id <SVDOMControllerRepresentedObject>)content;
{
    // Use the object's own ID if it has one. Otherwise make up our own
    if (self = [self init])
    {
        [self setRepresentedObject:content];
    }
    return self;
}

- (void)dealloc
{
    [self stopObservingDependencies];
    [_dependenciesTracker setDelegate:nil];
    [_dependenciesTracker removeAllDependencies];
    [_dependenciesTracker release];
    
    [_updateSelectors release];
    [_elementID release];
    [_context release];
    
    [_dragTypes release];
    
    [_moc release];
    
    [super dealloc];
}

#pragma mark Hierarchy

- (WEKWebEditorItem *)itemForDOMNode:(DOMNode *)node;
{
    // We're looking for a child of self, whose HTML element is the node
    
    WEKWebEditorItem *result = [self hitTestDOMNode:node];  // will hook up images etc. on-demand
    if (result == self) return nil;
    
    while ([result parentWebEditorItem] != self)
    {
        if (!result) return nil;
        
        result = [result parentWebEditorItem];
    }
    
    if ([result HTMLElement] != node) return nil;
    
    return result;
}

#pragma mark DOM Element Loading

- (DOMHTMLElement *)HTMLElement;
{
    DOMHTMLElement *result = [super HTMLElement];
    if (!result)
    {
        DOMDocument *document = [[[self parentWebEditorItem] HTMLElement] ownerDocument];
        if (!document)
        {
            document = [[self webEditor] HTMLDocument];
        }
        
        if (document)
        {
            [self loadHTMLElementFromDocument:document];
            if ([self isHTMLElementCreated]) result = [self HTMLElement];
        }
    }
    
    return result;
}

// No point observing if there's no DOM to affect
// At least that's the theory, I found in practice it broke dragging onto media placeholders
- (void)XsetHTMLElement:(DOMHTMLElement *)element;
{
    if (element)
    {
        [super setHTMLElement:element];
        [self startObservingDependencies];
    }
    else
    {
        [self stopObservingDependencies];
        [super setHTMLElement:element];
    }
}

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
    
    [context close];
    [context release];
}

- (void)loadHTMLElementFromDocument:(DOMDocument *)document;
{
    if ([self hasElementIdName])
    {
        // Load the element
        NSString *idName = [self elementIdName];
        DOMHTMLElement *element = (DOMHTMLElement *)[document getElementById:idName];
        
        
        if (element)
        {
            // Load descendants since they might share the same element
            [[self childWebEditorItems] makeObjectsPerformSelector:_cmd withObject:document];
            
            
            if (!_shouldPublishElementID)
            {
                // Ideally, as we're clearing out value from the DOM, should also stop referencing it ourselves. If an update occurs, the id should be regenerated. This isn't quite working yet though.
                [_elementID release]; _elementID = nil;
                [element setIdName:nil];
            }
        }
        
        [self setHTMLElement:element];
    }
}

- (NSString *)elementIdName;
{
    if (!_elementID)
    {
        // No ID has been specified by HTML writer, so generate our own
        _elementID = [[NSString alloc] initWithFormat:
                      @"%@-%p",
                      [self className],
                      self];
        
        // Are we sharing the same HTML element as parent? If so, assign same ID to it
        SVDOMController *parent = (id)[self parentWebEditorItem];
        if (![parent hasElementIdName])
        {
            [parent setElementIdName:[self elementIdName] includeWhenPublishing:NO];
        }
    }
    
    return _elementID;
}

- (BOOL)hasElementIdName; { return _elementID != nil; }

- (void)setElementIdName:(NSString *)ID includeWhenPublishing:(BOOL)shouldPublish;
{
    ID = [ID copy];
    [_elementID release]; _elementID = ID;
    
    _shouldPublishElementID = shouldPublish;
}

@synthesize HTMLContext = _context;

#pragma mark Selection

- (BOOL)shouldTrySelectingInline;
{
    return [[self representedObject] displayInline];
}

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
        [element removeAttribute:@"contenteditable"];
    }
    else
    {
        if ([textController isEditable]) [element setContentEditable:@"true"];
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
            // Articles update by re-using their child controllers where possible (this strategy may well be extended to other controllers one day). Thus we want children to continue observing dependencies while they're still in the tree.
            // For example this meant that article would stop child items from detecting a change in caption. #98794
            [self removeAllDependencies];//[self stopObservingDependencies];
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
    
    SVWebEditorViewController *viewController = [self webEditorViewController];
    
    
    // Ignore such preposterous claims if not even attached to an element yet
    if (![self HTMLElement] && [self hasElementIdName])
    {
        // But this could be because the Web Editor is mid reload. If so, do a full update (nasty, but best option available right now I think). #93345
        [viewController setNeedsUpdate];
        return;
    }
    
    
    // Try to get hold of the controller in charge of update coalescing
    if ([viewController respondsToSelector:@selector(scheduleUpdate)])
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
        
        [viewController performSelector:@selector(scheduleUpdate)];
    }
}

- (void)updateIfNeeded; // recurses down the tree
{
    [self retain];  // it's possible the update will deallocate self (e.g. articles)
    
    // Nil out ivar so it can be reused immediately
    // Also in case the update is async and hasn't finished yet
    NSSet *selectorStrings = _updateSelectors; _updateSelectors = nil;
    
    for (NSString *aSelectorString in selectorStrings)
    {
        SVWebEditorViewController *controller = [self webEditorViewController];
        //OBASSERT(controller); // actually, may well be nil due to an update elsewhere in the hierarchy. #97474
        [controller performSelector:@selector(willUpdate)];
        
        [self performSelector:NSSelectorFromString(aSelectorString)];
    }
    [selectorStrings release];
    
    
    // Carry on updating, *unless* the update happened to remove us from the tree. Tends to happen for rich text
    if ([self webEditor]) [super updateIfNeeded];
    
    [self release];
}

#pragma mark Size Binding

@synthesize width = _width;
- (void)setWidth:(NSNumber *)width;
{
    width = [width copy];
    [_width release]; _width = width;
    
    
}

#pragma mark Generic Dependencies

- (NSSet *)dependencies { return [_dependenciesTracker dependencies]; }

- (void)addDependency:(KSObjectKeyPathPair *)pair; { [_dependenciesTracker addDependency:pair]; }

- (void)removeAllDependencies; { [_dependenciesTracker removeAllDependencies]; }

- (BOOL)isObservingDependencies; { return [_dependenciesTracker isObservingDependencies]; }

- (void)startObservingDependencies;
{
    [_dependenciesTracker startObservingDependencies];
    [super startObservingDependencies]; // recurse
}

- (void)stopObservingDependencies;
{
    [_dependenciesTracker stopObservingDependencies];
    [super stopObservingDependencies]; // recurse
}

- (void)itemWillMoveToParentWebEditorItem:(WEKWebEditorItem *)newParentItem;
{
    [super itemWillMoveToParentWebEditorItem:newParentItem];
    
    // Turn off dependencies before move to match parent
    if (![newParentItem isObservingDependencies])
    {
        [self stopObservingDependencies];
    }
}

#pragma mark Content

@synthesize managedObjectContext = _moc;

- (void)setRepresentedObject:(id)object;
{
    [super setRepresentedObject:object];
    
    if (![self managedObjectContext] &&
        [object respondsToSelector:@selector(managedObjectContext)])
    {
        [self setManagedObjectContext:[object managedObjectContext]];
    }
}

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
    DOMRange *range = [self DOMRange];
    
    result = [webEditor shouldChangeTextInDOMRange:range];
    if (result)
    {
        [element ks_removeFromParentNode];
        [self removeFromParentWebEditorItem];
    }
    
    [range detach];
}

- (BOOL)shouldHighlightWhileEditing; { return NO; }

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
    DOMElement *graphic = [self HTMLElement];
        
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
    if ([[style cssFloat] isEqualToString:@"right"] ||
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

- (unsigned int)resizingMask
{
    return [[self enclosingGraphicDOMController] resizingMask];
}

- (void)resizeToSize:(NSSize)size byMovingHandle:(SVGraphicHandle)handle; { }

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

#pragma mark Relative Position

- (NSArray *)relativePositionDOMElements;
{
    DOMElement *result = [self HTMLElement];
    
    OBPOSTCONDITION(result);
    return [NSArray arrayWithObject:result];
}

- (void)moveToRelativePosition:(CGPoint)position;
{
    // Display space currently occupied…
    [self setNeedsDisplay];
    
    
    // Make the move
    _moving = YES;
    _relativePosition = position;
    
    for (DOMElement *anElement in [self relativePositionDOMElements])
    {
        DOMCSSStyleDeclaration *style = [anElement style];
        [style removeProperty:@"-webkit-transition-duration"];
        
        [style setPosition:@"relative"];
        [style setZIndex:@"9999"];
        
        
        [style setLeft:[[[NSNumber numberWithFloat:position.x] description]
                        stringByAppendingString:@"px"]];
        [style setTop:[[[NSNumber numberWithFloat:position.y] description]
                       stringByAppendingString:@"px"]];
    }
    
    
    // …and also new space
    [self setNeedsDisplay];
}

- (void)moveToPosition:(CGPoint)position;
{
    // Take existing offset into account
    CGPoint currentPosition = [self positionIgnoringRelativePosition];
    
    CGPoint relativePosition = CGPointMake(position.x - currentPosition.x,
                                           position.y - currentPosition.y);
    
    [self moveToRelativePosition:relativePosition];
}

- (void)removeRelativePosition:(BOOL)animated;
{
    for (DOMElement *anElement in [self relativePositionDOMElements])
    {
        DOMCSSStyleDeclaration *style = [anElement style];
        
        // Is there any way we can turn position off after animation?
        if (animated)
        {
            [style setProperty:@"-webkit-transition-property" value:@"left, top" priority:nil];
            [style setProperty:@"-webkit-transition-duration" value:@"0.25s" priority:nil];
            
            [self performSelector:@selector(removeRelativePositioningAnimationDidEnd)
                       withObject:nil
                       afterDelay:0.25];
        }
        else
        {
            [style setPosition:nil];
            [style setZIndex:nil];
            
            _moving = NO;
            [self setNeedsDisplay];
        }
        
        _relativePosition = CGPointZero;
        [style setLeft:nil];
        [style setTop:nil];
    }
}

- (BOOL)hasRelativePosition; { return _moving; }

- (CGPoint)positionIgnoringRelativePosition;
{
    CGPoint result = [self position];
    result.x -= _relativePosition.x;
    result.y -= _relativePosition.y;
    
    return result;
}

- (NSRect)rectIgnoringRelativePosition;
{
    NSRect result = [self selectionFrame];
    result.origin.x -= _relativePosition.x;
    result.origin.y -= _relativePosition.y;
    
    return result;
}

- (void)removeRelativePositioningAnimationDidEnd;
{
    for (DOMElement *anElement in [self relativePositionDOMElements])
    {
        DOMCSSStyleDeclaration *style = [anElement style];
        [style setPosition:nil];
        [style setZIndex:nil];
    }
    
    _moving = NO;
    [self setNeedsDisplay];
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

- (NSRect)drawingRect;
{
    // Fast-track; editing items cover the whole screen with darkening effect
    if ([self isEditing] && [self shouldHighlightWhileEditing])
    {
        return [[[self HTMLElement] documentView] bounds];
    }
    
    
    return [super drawingRect];
}
    
- (void)drawRect:(NSRect)dirtyRect inView:(NSView *)view;
{
    if ([self isEditing] && [self shouldHighlightWhileEditing])
    {
        // Darken area around us
        // Clip the rect covering editing item since we want to appear normal
        CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
        CGContextSaveGState(context);
        
        CGRect unclippedRect = NSRectToCGRect([self selectionFrame]);
        
        CGContextBeginPath(context);
        CGContextAddRect(context, CGRectInfinite); 
        CGContextAddRect(context, unclippedRect);
        CGContextEOClip(context);
        
        // Draw everything else slightly darkened
        [[NSColor colorWithCalibratedWhite:0.25 alpha:0.25] set];
        NSRectFillUsingOperation(dirtyRect, NSCompositeSourceOver);
        
        CGContextRestoreGState(context);
    }
    
    
    [super drawRect:dirtyRect inView:view];
}

- (KSSelectionBorder *)newSelectionBorder;
{
    KSSelectionBorder *result = [super newSelectionBorder];
    
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
    if ([[self enclosingGraphicDOMController] hasRelativePosition]) 
    {
        [result setEditing:YES];
    }
    
    return result;
}

#pragma mark KVO

- (void)dependenciesTracker:(KSDependenciesTracker *)tracker didObserveChange:(NSDictionary *)change forDependency:(KSObjectKeyPathPair *)dependency;
{
    [self setNeedsUpdate];
}

@end


#pragma mark -


@implementation SVContentObject (SVDOMController)

- (SVDOMController *)newDOMController;
{
    return [[SVDOMController alloc] initWithRepresentedObject:self];
}

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

- (BOOL)isObservingDependencies;
{
    WEKWebEditorItem *parent = [self parentWebEditorItem];
    return (parent ? [parent isObservingDependencies] : YES);
}

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

- (DOMNode *)previousDOMNode; { return [[self HTMLElement] previousSibling]; }

- (DOMNode *)nextDOMNode; { return [[self HTMLElement] nextSibling]; }

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

