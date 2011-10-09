//
//  SVDOMController.m
//  Sandvox
//
//  Created by Mike on 13/12/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVDOMController.h"

#import "SVContentDOMController.h"
#import "SVSidebarDOMController.h"
#import "SVPlugInDOMController.h"
#import "SVTextDOMController.h"
#import "SVWebEditorViewController.h"

#import "DOMNode+Karelia.h"
#import "NSResponder+Karelia.h"


@implementation SVDOMController

#pragma mark Init & Dealloc

- (id)init;
{
    [super init];
    
    _anchorPoint = CGPointMake(0.5, 0.5);
    
    _dependenciesTracker = [[KSDependenciesTracker alloc] initWithObservingOptions:NSKeyValueObservingOptionPrior];
    [_dependenciesTracker stopObservingDependencies];   // little dance so that subclasses start...
    [_dependenciesTracker setDelegate:self];
    //[self startObservingDependencies];                  // ...observing extra dependencies
    
    return self;
}

- (void)dealloc
{
    [self stopObservingDependencies];
    [_dependenciesTracker setDelegate:nil];
    [_dependenciesTracker removeAllDependencies];
    [_dependenciesTracker release];
    
    [_updateSelectors release];
    [_context release];
    
    [_dragTypes release];
    
    [_moc release];
    [_elementInfo release];
    
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

// No point observing if there's no DOM to affect
// At least that's the theory, I found in practice it broke dragging onto media placeholders
/*- (void)XsetHTMLElement:(DOMHTMLElement *)element;
{
    if (element)
    {
        [super setNode:element];
        [self startObservingDependencies];
    }
    else
    {
        [self stopObservingDependencies];
        [super setNode:element];
    }
}*/

- (void)setNode:(DOMNode *)element
{
    if (element)
    {
        // Load descendants since they might share the same element
        [[self childWebEditorItems] makeObjectsPerformSelector:@selector(HTMLElement)];
        
        
        if (!_shouldPublishElementID)
        {
            // Ideally, as we're clearing out value from the DOM, should also stop referencing it ourselves. If an update occurs, the id should be regenerated. This isn't quite working yet though.
            //[_elementID release]; _elementID = nil;
            [element setIdName:nil];
        }
    }
    
    [super setNode:element];
}

- (void)loadNode
{
    if ([self elementIdName])
    {
        [super loadNode];
        
        // I've found that occasionally, loading fails because the <BODY> element hasn't been created yet. Wait for that to happen
        while (![self isNodeLoaded])
        {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate distantPast]];
            [super loadNode];
        }
        
        return;
    }
    
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
    [self setNode:element];
    
    
    // Insert controllers
    for (WEKWebEditorItem *aController in [[context rootDOMController] childWebEditorItems])
    {
        [self addChildWebEditorItem:aController];
    }
    
    [context close];
    [context release];
}

- (void)loadPlaceholderDOMElement;
{
    DOMElement *element = [[[self ancestorNode] ownerDocument] createElement:@"DIV"];
    [[element style] setDisplay:@"none"];
    [self setNode:(DOMHTMLElement *)element];
}

- (DOMHTMLDocument *)HTMLDocument;
{
    DOMHTMLDocument *result = [super HTMLDocument];
    if (!result) result = [[[self parentWebEditorItem] HTMLElement] ownerDocument];
    if (!result) result = [[self webEditor] HTMLDocument];
    return result;
}

@synthesize elementInfo = _elementInfo;
@synthesize shouldIncludeElementIdNameWhenPublishing = _shouldPublishElementID;

@synthesize HTMLContext = _context;

#pragma mark Selection

- (BOOL)shouldTrySelectingInline;
{
    BOOL result = NO;
    
    id object = [self representedObject];
    if ([object respondsToSelector:@selector(displayInline)])
    {
        result = [object displayInline];
    }
    
    return result;
}

#pragma mark Updating

- (void)willUpdateWithNewChildController:(WEKWebEditorItem *)newChildController;
{
    // Helper method that:
    //  A) swaps the new controller out for an existing one if possible
    //  B) runs scripts for the new controller
    
    
    NSObject *object = [newChildController representedObject];
    
    for (WEKWebEditorItem *anOldController in [self childWebEditorItems])
    {
        if ([[anOldController representedObject] isEqual:object])
        {
            DOMNode *oldElement = [anOldController HTMLElement];
            if (oldElement)
            {
                // Bring back the old element!
                DOMElement *element = [newChildController HTMLElement];
                [[element parentNode] replaceChild:oldElement oldChild:element];
                
                // Bring back the old controller!
                [[newChildController parentWebEditorItem] replaceChildWebEditorItem:newChildController
                                                                               with:anOldController];
                return;
            }
        }
    }
    
    
    // Force update the controller to run scripts etc. #99997
    [newChildController setNeedsUpdate]; [newChildController updateIfNeeded];
}

- (void)updateWithHTMLString:(NSString *)html context:(SVWebEditorHTMLContext *)context
{
    //[[context rootDOMController] setWebEditorViewController:[self webEditorViewController]];
    
    
    // Update DOM
    DOMElement *oldElement = [self HTMLElement];
    DOMDocument *doc = [oldElement ownerDocument];
    WEKWebEditorItem *parent = [self parentWebEditorItem];
    [(DOMHTMLElement *)[self HTMLElement] setOuterHTML:html];
    
    while ([parent HTMLElement] == oldElement)  // ancestors may be referencing the same node
    {
        // Reset element, ready to reload
        [parent setElementIdName:[[[[[context rootElement] subelements] lastObject] attributesAsDictionary] objectForKey:@"id"]];
        [parent setNode:nil];
        
        parent = [parent parentWebEditorItem];
    }
    
    
    // Create controllers
    SVContentDOMController *contentController = [[SVContentDOMController alloc] initWithWebEditorHTMLContext:context
                                                                                                        node:doc];
    
    
    // Copy across extra dependencies, but I'm not sure why. Mike
    [[self mutableSetValueForKeyPath:@"parentWebEditorItem.dependencies"] unionSet:[contentController dependencies]];
    
    
    // Re-use any existing graphic controllers when possible
    for (WEKWebEditorItem *aController in [contentController childWebEditorItems])
    {
        for (WEKWebEditorItem *newChildController in [aController childWebEditorItems])
        {
            [self willUpdateWithNewChildController:newChildController];
        }
    }
    
    
    
    // Hook up new DOM Controllers
    [self stopObservingDependencies];
    [self didUpdateWithSelector:@selector(update)]; // must inform now, before are removed from the tree
    
    [[self retain] autorelease];    // since the replacement could easily dealloc us otherwise!
    [[self parentWebEditorItem] replaceChildWebEditorItem:self withItems:[contentController childWebEditorItems]];
    
    [contentController release];
}

- (void)update;
{
    // Tear down dependencies etc.
    [self removeAllDependencies];
    
    
    // Write HTML
    NSMutableString *htmlString = [[NSMutableString alloc] init];
    
    SVWebEditorHTMLContext *context = [[SVWebEditorHTMLContext alloc]
                                       initWithOutputWriter:htmlString inheritFromContext:[self HTMLContext]];
    
    
    WEKWebEditorItem *parent = [self parentWebEditorItem];
    id <SVComponent> parentComponent = [parent representedObject];
    while (parent && !parentComponent)
    {
        parent = [parent parentWebEditorItem];
        parentComponent = [parent representedObject];
    }
    
    if (parentComponent)
    {
        [context beginGraphicContainer:parentComponent];
        [self writeUpdateHTML:context];
        [context endGraphicContainer];
    }
    else
    {
        [self writeUpdateHTML:context];
    }
    
    
    // Copy top-level dependencies across to parent. #79396
    [context flush];    // you never know!
    
    
    // Turn observation back on. #92124
    //[self startObservingDependencies];
    
    
    // Bring end body code into the html
    [context writeEndBodyString];
    
    
    [context close];
    [self updateWithHTMLString:htmlString context:context];
    
    
    // Tidy
    [htmlString release];
    [context release];
}

- (void)writeUpdateHTML:(SVHTMLContext *)context;
{
    [[self representedObject] writeHTML:context];
}

- (BOOL)canUpdate;
{
    return [[self representedObject] conformsToProtocol:@protocol(SVComponent)];
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
        [[element style] setProperty:@"-webkit-nbsp-mode" value:@"space" priority:@""]; // so spacing doesn't change when editing turns off. #133624
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
            // Rich Text updates by re-using their child controllers where possible (this strategy may well be extended to other controllers one day). Thus we want children to continue observing dependencies while they're still in the tree.
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
    if (![self isNodeLoaded] && [self elementIdName])
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
        
        [controller willUpdate];
        [self performSelector:NSSelectorFromString(aSelectorString)];
    }
    [selectorStrings release];
    
    
    // Carry on updating, *unless* the update happened to remove us from the tree. Tends to happen for rich text
    if ([self webEditor]) [super updateIfNeeded];
    
    [self release];
}

#pragma mark Generic Dependencies

- (NSSet *)dependencies { return [_dependenciesTracker dependencies]; }

- (void)addDependenciesObject:(KSObjectKeyPathPair *)pair; { [_dependenciesTracker addDependency:pair]; }
- (void)addDependency:(KSObjectKeyPathPair *)pair; { [self addDependenciesObject:pair]; }

- (void)removeDependenciesObject:(KSObjectKeyPathPair *)pair { OBASSERT_NOT_REACHED("shouldn't remove"); }

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

#pragma mark Delete

- (void)delete:(id)sender forwardingSelector:(SEL)action;
{
    id object = [self representedObject];
    if ([self isSelectable] && [object respondsToSelector:@selector(setHidden:)])
    {
        [object setValue:NSBOOL(YES) forKey:@"hidden"];
    }
    else
    {
        [self makeNextResponderDoCommandBySelector:action];
    }
}

- (void)delete:(id)sender;
{
    [self delete:sender forwardingSelector:_cmd];
}

- (void)deleteForward:(id)sender;
{
    [self delete:sender forwardingSelector:_cmd];
}

- (void)deleteBackward:(id)sender;
{
    [self delete:sender forwardingSelector:_cmd];
}

#pragma mark Editing

- (BOOL)shouldHighlightWhileEditing; { return NO; }

#pragma mark Resizing

- (void)updateSize;
{
    // Workaround for #94381. Make sure any selectable parent redraws
    [[[self selectableAncestors] lastObject] setNeedsDisplay];
    
    // Call super so we don't get in a loop of marking for update
    [super updateWidth];
    [super updateHeight];
    
    
    // Finish
    [self didUpdateWithSelector:_cmd];
}

- (void)updateWidth; { [self setNeedsUpdateWithSelector:@selector(updateSize)]; }
- (void)updateHeight; { [self setNeedsUpdateWithSelector:@selector(updateSize)]; }

- (unsigned int)resizingMask
{
    unsigned int result = [super resizingMask];
    if (!result) result = [[self enclosingGraphicDOMController] resizingMask];
    return result;
}

- (void)resizeToSize:(NSSize)size byMovingHandle:(SVGraphicHandle)handle;
{
    [super resizeToSize:size byMovingHandle:handle];
    
    // Force immediate update
    [self updateIfNeeded];
}

#pragma mark Moving

/*  Probably don't really want to move this item, but the graphic as a whole
 */

- (BOOL)moveToPosition:(CGPoint)position event:(NSEvent *)event;
{
    // See if super fancies a crack
    if ([super moveToPosition:position event:event]) return YES;
    
    
    WEKWebEditorItem <SVGraphicContainerDOMController> *dragController = [self graphicContainerDOMController];
    if ([dragController graphicContainerDOMController]) dragController = [dragController graphicContainerDOMController];
    
    [dragController moveGraphicWithDOMController:self toPosition:position event:event];
    
    
    // Starting a move turns off selection handles so needs display
    if (dragController && ![self hasRelativePosition])
    {
        [self setNeedsDisplay];
        //_moving = YES;
    }
    
    return (dragController != nil);
}

- (void)moveEnded;
{
    [super moveEnded];
    [self removeRelativePosition:YES];
}

- (CGPoint)position;
{
    NSRect frame = [self frame];
    CGPoint anchor = [self anchorPoint];
    
    CGPoint result = CGPointMake(frame.origin.x + (anchor.x * frame.size.width),
                                 frame.origin.y + (anchor.y * frame.size.height));
                                 
    return result;
}

@synthesize anchorPoint = _anchorPoint;

- (CGPoint)anchorPointToGivePosition:(CGPoint)position;
{
    NSRect frame = [self frame];
    
    CGPoint result = CGPointMake((position.x - frame.origin.x) / frame.size.width,
                                 (position.y - frame.origin.y) / frame.size.height);
    
    return result;
}

#pragma mark Relative Position

- (NSArray *)relativePositionDOMElements;
{
    DOMElement *result = [self HTMLElement];
    
    OBPOSTCONDITION(result);
    return [NSArray arrayWithObject:result];
}

- (void)setRelativePosition:(CGPoint)position;
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
    CGPoint currentPosition = [self position];
    
    CGPoint relativePosition = CGPointMake(_relativePosition.x + (position.x - currentPosition.x),
                                           _relativePosition.y + (position.y - currentPosition.y));
    
    [self setRelativePosition:relativePosition];
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
    DOMElement *selectionElement = [self HTMLElement];
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


@implementation WEKWebEditorItem (SVDOMController)

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
    // Update might change the .childWebEditorItems property, so retain during. #137521
    NSArray *children = [[self childWebEditorItems] retain];
    [children makeObjectsPerformSelector:_cmd];
    [children release];
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

#pragma mark Moving

- (void)moveItemUp:(SVDOMController *)item;
{
    // By default have no idea how to move, so get parent to move us instead
    [[self parentWebEditorItem] moveItemUp:self];
}

- (void)moveItemDown:(SVDOMController *)item;
{
    // By default have no idea how to move, so get parent to move us instead
    [[self parentWebEditorItem] moveItemDown:self];
}

- (void)moveUp; { [[self parentWebEditorItem] moveItemUp:self]; }

- (void)moveDown; { [[self parentWebEditorItem] moveItemDown:self]; }

#pragma mark Drag & Drop

- (NSArray *)registeredDraggedTypes; { return nil; }

@end


#pragma mark -


@implementation WEKDOMController (SVDOMController)

- (DOMNode *)previousDOMNode; { return [[self node] previousSibling]; }

- (DOMNode *)nextDOMNode; { return [[self node] nextSibling]; }

#pragma mark Moving

- (void)exchangeWithPreviousDOMNode;     // swaps with previous sibling node
{
    DOMNode *element = [self node];
    
    [[element parentNode] insertBefore:[element previousSibling]
                              refChild:[element nextSibling]];
}

- (void)exchangeWithNextDOMNode;   // swaps with next sibling node
{
    DOMNode *element = [self node];
    
    [[element parentNode] insertBefore:[element nextSibling]
                              refChild:element];
}

@end

