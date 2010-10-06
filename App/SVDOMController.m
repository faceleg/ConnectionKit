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
    [self setObservesDependencies:YES]; // in case a dependency got setup before -init
    
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
    
    [_elementID release];
    [_context release];
    
    [super dealloc];
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

- (void)update;
{
    [self didUpdate];
}

- (void)didUpdate;
{
    _needsUpdate = NO;
    
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
    SVTextDOMController *textController = [self textDOMController];
    if ([self isEditing])
    {
        [[textController textHTMLElement] removeAttribute:@"contenteditable"];
    }
    else
    {
        [textController setEditable:[textController isEditable]];
    }
}

#pragma mark Update Scheduling

@synthesize needsUpdate = _needsUpdate;

- (void)setNeedsUpdate;
{
    // Ignore such preposterous claims if not even attached to an element yet
    if (![self HTMLElement] && [self elementIdName]) return;
    
    
    // Once we're marked for update, no point continuing to observe
    [self setObservesDependencies:NO];
    
    
    // By default, controllers don't know how to update, so must update parent instead
    if ([self methodForSelector:@selector(update)] == 
        [SVDOMController instanceMethodForSelector:@selector(update)])
    {
        return [super setNeedsUpdate];
    }
    
    
    // Try to get hold of the controller in charge of update coalescing
	SVWebEditorViewController *controller = [self webEditorViewController];
    if ([controller respondsToSelector:@selector(scheduleUpdate)] || ![self webEditor])
    {
        _needsUpdate = YES;
        [controller performSelector:@selector(scheduleUpdate)];
    }
    else
    {
        OBASSERT(controller);
        [self update];
    }
}

- (void)updateIfNeeded; // recurses down the tree
{
    if ([self needsUpdate])
    {
        SVWebEditorViewController *controller = [self webEditorViewController];
        OBASSERT(controller);
        [controller performSelector:@selector(willUpdate)];
        
        [self update];
        _needsUpdate = NO;  // in case the update is async and hasn't finished yet
    }
    
    [super updateIfNeeded];
}

#pragma mark Dependencies

- (NSSet *)dependencies { return [[_dependencies copy] autorelease]; }

- (void)startObservingDependency:(KSObjectKeyPathPair *)pair;
{
    [[pair object] addObserver:self
                    forKeyPath:[pair keyPath]
                       options:NSKeyValueObservingOptionPrior
                       context:sWebViewDependenciesObservationContext];
}

- (void)startObservingDependencies;
{
    for (KSObjectKeyPathPair *aDependency in [self dependencies])
    {
        [self startObservingDependency:aDependency];
    }
}

- (void)stopObservingDependencies;
{
    for (KSObjectKeyPathPair *aDependency in [self dependencies])
    {
        [[aDependency object] removeObserver:self forKeyPath:[aDependency keyPath]];
    }
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
            if ([self observesDependencies]) [self startObservingDependency:pair];
        }
    }
}

- (void)removeAllDependencies;
{
    if ([self observesDependencies]) [self stopObservingDependencies];
    [_dependencies removeAllObjects];
}

@synthesize observesDependencies = _isObservingDependencies;
- (void)setObservesDependencies:(BOOL)observe;
{
    if (observe && ![self observesDependencies]) [self startObservingDependencies];
    if (!observe && [self observesDependencies]) [self stopObservingDependencies];
    
    _isObservingDependencies = observe;
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

- (unsigned int)resizingMask
{
    DOMElement *element = [self selectableDOMElement];
    
    
    NSString *className = [[self HTMLElement] className];
    DOMCSSStyleDeclaration *style = [[element ownerDocument] getComputedStyle:element pseudoElement:@""];
    
    unsigned int result = kCALayerRightEdge; // default to adjustment from right-hand edge
    
    
    // Decide the mask by testing the DOM. For inline elements, not hard. But for block-level stuff I haven't figured out the right stuff to test, so fall back to checking class name since we ought to be in control of that.
    if ([[style getPropertyValue:@"float"] isEqualToString:@"right"] ||
        [[style textAlign] isEqualToString:@"right"] ||
        [className rangeOfString:@" right"].location != NSNotFound)
    {
        result = kCALayerLeftEdge;
    }
    else if ([[style textAlign] isEqualToString:@"center"] ||
             [className rangeOfString:@" center"].location != NSNotFound)
    {
        result = result | kCALayerLeftEdge;
    }
    
    
    // Finish up
    return result;
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
    
    
    // Apply constraints, UNLESS the command key is held down. Why not use current NSEvent? - Mike
    NSSize size = bounds.size;
    if ((GetCurrentKeyModifiers() & cmdKey) == 0)
	{
        size = [self constrainSize:size handle:handle];
    }
    
    
    // Finally, we can go ahead and resize
    [self resizeToSize:size byMovingHandle:handle];
    
    
    return handle;
}

- (NSSize)constrainSize:(NSSize)size handle:(SVGraphicHandle)handle;
{
    // Whew, what a lot of questions! Now, should this drag be disallowed on account of making the DOM element bigger than its container? #84958
    DOMNode *parent = [[self HTMLElement] parentNode];
    DOMCSSStyleDeclaration *style = [[[self HTMLElement] ownerDocument] 
                                     getComputedStyle:(DOMElement *)parent
                                     pseudoElement:@""];
    
    CGFloat maxWidth = [[style width] floatValue];
    if (size.width > maxWidth) size.width = maxWidth;
    
    
    return size;
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
    SVWebEditorViewController *controller = [self webEditorViewController];
    if ([controller respondsToSelector:_cmd])
    {
        [controller performSelector:_cmd];
    }
}

- (void)updateIfNeeded; // recurses down the tree
{
    // The update may well have meant no children need updating any more. If so, no biggie as this recursion should do nothing
    [[self childWebEditorItems] makeObjectsPerformSelector:_cmd];
}

- (SVWebEditorHTMLContext *)HTMLContext { return nil; }

- (void)setObservesDependencies:(BOOL)observe; { }

#pragma mark Drag & Drop

- (NSArray *)registeredDraggedTypes; { return nil; }

- (WEKWebEditorItem *)hitTestDOMNode:(DOMNode *)node
                       draggingInfo:(id <NSDraggingInfo>)info;
{
    OBPRECONDITION(node);
    
    WEKWebEditorItem *result = nil;
    
    if ([node ks_isDescendantOfElement:[self HTMLElement]] || ![self HTMLElement])
    {
        for (WEKWebEditorItem *anItem in [self childWebEditorItems])
        {
            result = [anItem hitTestDOMNode:node draggingInfo:info];
            if (result) break;
        }
        
        if (!result)
        {
            NSArray *types = [self registeredDraggedTypes];
            if ([[info draggingPasteboard] availableTypeFromArray:types]) result = self;
        }
    }
    
    return result;
}

@end

