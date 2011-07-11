//
//  SVSidebarDOMController.m
//  Sandvox
//
//  Created by Mike on 07/05/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVSidebarDOMController.h"

#import "SVArticleDOMController.h"
#import "SVAttributedHTML.h"
#import "SVGraphicDOMController.h"
#import "KTPage.h"
#import "SVTextAttachment.h"
#import "SVWebEditorViewController.h"
#import "WebEditingKit.h"

#import "NSArray+Karelia.h"
#import "NSColor+Karelia.h"
#import "DOMNode+Karelia.h"


@interface SVSidebarDOMController ()

// Pagelets
- (NSRect)rectOfDropZoneBelowDOMNode:(DOMNode *)node1
                        aboveDOMNode:(DOMNode *)node2
                              height:(CGFloat)height;
- (NSRect)rectOfDropZoneBelowDOMNode:(DOMNode *)node height:(CGFloat)height;
- (NSRect)rectOfDropZoneAboveDOMNode:(DOMNode *)node height:(CGFloat)minHeight;
- (NSRect)rectOfDropZoneInDOMElement:(DOMElement *)element
                           belowNode:(DOMNode *)node
                           minHeight:(CGFloat)minHeight;

@end


#pragma mark -


@implementation SVSidebarDOMController

#pragma mark Init/Dealloc

static NSString *sSVSidebarDOMControllerPageletsObservation = @"SVSidebarDOMControllerPageletsObservation";

- (id)initWithPageletsController:(SVSidebarPageletsController *)pageletsController;
{
    // Get pagelets controller nicelt setup
    OBPRECONDITION(pageletsController);
    
    
    [self init];
    [self setElementIdName:@"sidebar-container" includeWhenPublishing:YES];
    
    _pageletsController = [pageletsController retain];
    [_pageletsController addObserver:self
                          forKeyPath:@"arrangedObjects"
                             options:0
                             context:sSVSidebarDOMControllerPageletsObservation];
    
    return self;
}

- (void)awakeFromHTMLContext:(SVWebEditorHTMLContext *)context;
{
    [super awakeFromHTMLContext:context];
    [self setPageletDOMControllers:[self childWebEditorItems]];
}

- (void)dealloc;
{
    [_pageletsController removeObserver:self forKeyPath:@"arrangedObjects"];
    [_pageletsController release];
    
    [_DOMControllers release];
    [_sidebarDiv release];
    [_contentElement release];
    
    [super dealloc];
}

#pragma mark DOM

@synthesize sidebarDivElement = _sidebarDiv;
@synthesize contentDOMElement = _contentElement;

- (void)loadHTMLElementFromDocument:(DOMDocument *)document;
{
    [super loadHTMLElementFromDocument:document];
    
    // Also seek out sidebar divs
    [self setSidebarDivElement:[document getElementById:@"sidebar"]];
    [self setContentDOMElement:[document getElementById:@"sidebar-content"]];
}

#pragma mark Updating

+ (void)loadHTMLElementsOfDOMControllers:(NSArray *)controllers fromDocumentFragment:(DOMDocumentFragment *)fragment;
{
    // TODO: ought to search more than top-level of tree
    NSDictionary *controllersByID = [[NSDictionary alloc]
                                     initWithObjects:controllers
                                     forKeys:[controllers valueForKey:@"elementIdName"]];
    
    DOMHTMLElement *anElement = [fragment firstChildOfClass:[DOMElement class]];
    while (anElement)
    {
        NSString *ID = [anElement getAttribute:@"id"];
        if (ID)
        {
            SVDOMController *controller = [controllersByID objectForKey:ID];
            [controller setHTMLElement:anElement];
        }
        
        anElement = [anElement nextSiblingOfClass:[DOMElement class]];
    }
    
    [controllersByID release];
}

- (void)updatePageletOrdering;
{
    // Arrange DOM nodes to match. Start by removing all
    DOMElement *contentElement = [self contentDOMElement];
    [[contentElement mutableChildDOMNodes] removeAllObjects];
    
    
    // Genrate markup for how the sidebar should look
    NSArray *pagelets = [[self pageletsController] arrangedObjects];
    NSMutableString *html = [[NSMutableString alloc] init];
    
    SVWebEditorHTMLContext *context = [[SVWebEditorHTMLContext alloc]
                                       initWithOutputWriter:html
                                       inheritFromContext:[self HTMLContext]];
    
    [context beginGraphicContainer:[self representedObject]];
    [context writeGraphics:pagelets];
    [context endGraphicContainer];
    
    
    // Load HTML into DOM, hooking up to controllers
    DOMDocumentFragment *fragment = [(DOMHTMLDocument *)[[self HTMLElement] ownerDocument]
                                     createDocumentFragmentWithMarkupString:html
                                     baseURL:nil];
    [html release];
    
    NSMutableArray *controllers = [[[context rootDOMController] childWebEditorItems] mutableCopy];
    [context release];
    
    [[self class] loadHTMLElementsOfDOMControllers:controllers fromDocumentFragment:fragment];
    
    
    // Figure out correct DOM controllers for pagelets
    SVGraphic *aPagelet;
    WEKWebEditorItem *nextController = nil;
    
    for (NSUInteger i = [controllers count] - 1; i < NSNotFound;)
    {
        aPagelet = [[controllers objectAtIndex:i] representedObject];
        
        
        // Grab controller for item. Create it if needed
        id controller = [self hitTestRepresentedObject:aPagelet];
        if (controller)
        {
            // Update attributes from new element
            DOMElement *element = [[controllers objectAtIndex:i] HTMLElement];
            if (element)
            {
                [[controller HTMLElement] setAttribute:@"class" value:[element getAttribute:@"class"]];
            }
            [controllers replaceObjectAtIndex:i withObject:controller];
        }
        else
        {            
            controller = [controllers objectAtIndex:i];
            [controller loadPlaceholderDOMElementInDocument:[contentElement ownerDocument]];
            [self addChildWebEditorItem:controller];
            [controller setHTMLContext:[self HTMLContext]];
            
            [controller setNeedsUpdate];
            [controller updateIfNeeded];    // push it through quickly
        }
        
        i--;
        
        // Insert before what should be its next sibling
        DOMElement *element = [controller HTMLElement];
        if (element)    // #119039
        {
            [contentElement insertBefore:element
                                refChild:[nextController HTMLElement]];
        }
        
        
        // Loop
        nextController = controller;
    }
    
    
    // Store the new controllers. Ditch any from -childDOMControllers that are no longer present
    for (SVDOMController *aController in [self pageletDOMControllers])
    {
        if (![controllers containsObjectIdenticalTo:aController])
        {
            OBASSERT([aController parentWebEditorItem] == self);
            [aController removeFromParentWebEditorItem];
        }
    }
    
    [self setPageletDOMControllers:controllers];
    [controllers release];
    
    
    // Hide the sidebar when empty to approximate how it would be published. #100208
    if ([pagelets count])
    {
        [[[self sidebarDivElement] style] removeProperty:@"opacity"];
    }
    else
    {
        [[[self sidebarDivElement] style] setProperty:@"opacity" value:@"0" priority:@""];
    }
    
    
    // Finish
    [self didUpdateWithSelector:_cmd];
}

- (SVSidebarDOMController *)sidebarDOMController; { return self; }

- (void)replaceChildWebEditorItem:(WEKWebEditorItem *)oldItem withItems:(NSArray *)newItems;
{
    [super replaceChildWebEditorItem:oldItem withItems:newItems];
    
    // Graphics might call this while updating. If so we want to reflect the change in our own items
    NSUInteger index = [[self pageletDOMControllers] indexOfObjectIdenticalTo:oldItem];
    if (index != NSNotFound)
    {
        NSMutableArray *controllers = [[self pageletDOMControllers] mutableCopy];
        [controllers replaceObjectsInRange:NSMakeRange(index, 1) withObjectsFromArray:newItems];
        [self setPageletDOMControllers:controllers];
        [controllers release];
    }
}

#pragma mark Pagelets Controller

@synthesize pageletDOMControllers = _DOMControllers;

@synthesize pageletsController = _pageletsController;

#pragma mark Placement Actions

- (void)placeSelection:(SVGraphicPlacement)placement;
{
    SVRichText *article = [[[self HTMLContext] page] article];
    NSMutableAttributedString *html = [[article attributedHTMLString] mutableCopy];
    
    SVWebEditorViewController *viewController = [self webEditorViewController];
    OBASSERT(viewController);
    
    for (SVGraphic *aGraphic in [[viewController graphicsController] selectedObjects])
    {
        // Remove from all pages
        [[aGraphic mutableSetValueForKey:@"sidebars"] removeAllObjects];
        
        // Insert at start of page
        NSAttributedString *graphicHTML = [NSAttributedString attributedHTMLStringWithGraphic:aGraphic];
        [[aGraphic textAttachment] setPlacement:[NSNumber numberWithInt:placement]];
        [html insertAttributedString:graphicHTML atIndex:0];
    }
    
    // Store html
    [article setAttributedHTMLString:html];
    [html release];
}

- (void)placeInline:(id)sender;
{
    [self placeSelection:SVGraphicPlacementInline];
}

- (void)placeAsCallout:(id)sender;
{
    [self placeSelection:SVGraphicPlacementCallout];
}

- (void)placeInSidebar:(id)sender;
{
    // Already there, so do nothing. Need to implement this otherwise view controller will have nowhere to send the message, and thus beep.
}

#pragma mark Insertion Actions

- (IBAction)insertPagelet:(id)sender;
{
    // Create element
    KTPage *page = [[self HTMLContext] page];
    if (!page) return NSBeep(); // pretty rare. #75495
    
    
    SVGraphic *pagelet = [SVGraphicFactory graphicWithActionSender:sender
                                    insertIntoManagedObjectContext:[page managedObjectContext]];
    
    
    // Insert it
    [pagelet awakeFromNew];
    
    [self addGraphic:pagelet];
}

- (void)addGraphic:(SVGraphic *)graphic;
{
    // Place at end of the sidebar
    NSUInteger index = [[self pageletsController] selectionIndex];
    if (index == NSNotFound) index = 0;
    [[self pageletsController] insertObject:graphic atArrangedObjectIndex:index];
    
    
    // Add to main controller too
    KSArrayController *controller = [[self webEditorViewController] graphicsController];
    
    [controller saveSelectionAttributes];
    @try
    {
        [controller setSelectsInsertedObjects:YES];
        [controller addObject:graphic];
    }
    @finally
    {
        [controller restoreSelectionAttributes];
    }
    
    // TODO: this duplicates -[SVWebEditorViewController _insertPageletInSidebar:] somewhat
}

- (void)paste:(id)sender;
{
    SVSidebarPageletsController *sidebarPageletsController = [self pageletsController];
    
    NSUInteger index = [sidebarPageletsController selectionIndex];
    if (index >= NSNotFound) index = 0;
    
    [sidebarPageletsController insertPageletsFromPasteboard:[NSPasteboard generalPasteboard]
                                      atArrangedObjectIndex:index];
}

#pragma mark Drop

/*  Similar to NSTableView's concept of dropping above a given row
 */
- (NSUInteger)indexOfDrop:(id <NSDraggingInfo>)dragInfo;
{
    NSUInteger result = NSNotFound;
    NSView *view = [[self HTMLElement] documentView];
    NSArray *pageletControllers = [self pageletDOMControllers];
    NSPoint location = [view convertPointFromBase:[dragInfo draggingLocation]];
    
    
    // Ideally, we're making a drop *before* a pagelet
    WEKWebEditorItem *previousItem = nil;
    NSUInteger i, count = [pageletControllers count];
    for (i = 0; i < count; i++)
    {
        // Calculate drop zone
        WEKWebEditorItem *anItem = [pageletControllers objectAtIndex:i];
        
        NSRect dropZone = [self rectOfDropZoneBelowDOMNode:[previousItem HTMLElement]
                                              aboveDOMNode:[anItem HTMLElement]
                                                    height:25.0f];
        
        
        // Is it a match?
        if ([view mouse:location inRect:dropZone])
        {
            result = i;
            break;
        }
        
        previousItem = anItem;
    }
    
    
    // If not, is it a drop *after* the last pagelet, or into an empty sidebar?
    if (result == NSNotFound)
    {
        NSRect dropZone = [self rectOfDropZoneInDOMElement:[self sidebarDivElement]
                                                 belowNode:[[pageletControllers lastObject] HTMLElement]
                                                 minHeight:25.0f];
        
        if ([view mouse:location inRect:dropZone])
        {
            result = [pageletControllers count];
        }
    }
    
    
    // There's nothing to do if the drop is same as source
    if (result != NSNotFound)
    {
        if ([dragInfo draggingSource] == [self webEditor])
        {
            NSArray *draggedItems = [[self webEditor] draggedItems];
            
            if (result >= 1 && [draggedItems containsObject:[pageletControllers objectAtIndex:result-1]])
            {
                result = NSNotFound;
            }
            else if (!(result >= [pageletControllers count]) &&
                     [draggedItems containsObject:[pageletControllers objectAtIndex:result]])
            {
                result = NSNotFound;
            }
        }
    }
    
    
    return result;
}

- (NSRect)rectOfDropZoneBelowDOMNode:(DOMNode *)node1
                        aboveDOMNode:(DOMNode *)node2
                              height:(CGFloat)height;
{
    OBPRECONDITION(node2);
    
    if (node1)
    {
        NSRect result = [self rectOfDropZoneAboveDOMNode:node2 height:25.0f];
        
        NSRect upperDropZone = [self rectOfDropZoneBelowDOMNode:node1
                                                         height:25.0f];
        result = NSUnionRect(upperDropZone, result);
        
        return result;
    }
    else
    {
        NSRect parentBox = [[node2 parentNode] boundingBox];
        NSRect nodeBox = [node2 boundingBox];
        
        CGFloat y = NSMinY(parentBox);
        NSRect result = NSMakeRect(NSMinX(nodeBox),
                                   y - 0.5*height,
                                   nodeBox.size.width,
                                   NSMinY(nodeBox) - y + height);
        
        return result;
    }
}

- (NSRect)rectOfDropZoneBelowDOMNode:(DOMNode *)node height:(CGFloat)height;
{
    NSRect nodeBox = [node boundingBox];
    
    // Claim the strip at the bottom of the node
    NSRect result = NSMakeRect(NSMinX(nodeBox),
                               NSMaxY(nodeBox) - 0.5*height,
                               nodeBox.size.width,
                               height);
    
    return result;
}

- (NSRect)rectOfDropZoneAboveDOMNode:(DOMNode *)node height:(CGFloat)height;
{
    NSRect nodeBox = [node boundingBox];
    
    NSRect result = NSMakeRect(NSMinX(nodeBox),
                               NSMinY(nodeBox) - 0.5*height,
                               nodeBox.size.width,
                               height);
    
    return result;
}

- (NSRect)rectOfDropZoneInDOMElement:(DOMElement *)element
                           belowNode:(DOMNode *)node
                           minHeight:(CGFloat)minHeight;
{
    //Normally equal to element's -boundingBox.
    NSRect result = [element boundingBox];
    
    
    //  But then shortened to only include the area below boundingBox
    if (node)
    {
        NSRect nodeBox = [node boundingBox];
        CGFloat nodeBottom = NSMaxY(nodeBox);
        
        result.size.height = NSMaxY(result) - nodeBottom;
        result.origin.y = nodeBottom;
    }
    
    
    //  Finally, expanded again to minHeight if needed.
    if (result.size.height < minHeight)
    {
        result = NSInsetRect(result, 0.0f, -0.5 * (minHeight - result.size.height));
    }
    
    
    return result;
}

- (NSArray *)registeredDraggedTypes;
{
    return NSARRAY((NSString *)kUTTypeItem, NSFilenamesPboardType, kSVGraphicPboardType);
}

#pragma mark NSDraggingDestination

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
{
    return [self draggingUpdated:sender];
}

- (NSDragOperation)dragOperation:(id <NSDraggingInfo>)dragInfo;
{
    NSDragOperation result = NSDragOperationNone;
    
    BOOL sourceIsWebEditor = ([dragInfo draggingSource] == [self webEditor]);
    
    
    // Figure out mask. Same logic is in SVArticleDOMController - can we refactor?
    NSDragOperation mask = [dragInfo draggingSourceOperationMask];
    if (sourceIsWebEditor)
    {
        result = mask & NSDragOperationGeneric;
    }
    if (!result) result = mask & NSDragOperationCopy;
    if (!result) result = mask & NSDragOperationGeneric;
    
    return result;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)dragInfo;
{
    NSDragOperation result = [self dragOperation:dragInfo];

    
    
    if (result && ([dragInfo draggingSource] == [self webEditor]))
    {
        NSUInteger dropIndex = [self indexOfDrop:dragInfo];
        if (dropIndex != NSNotFound)
        {
                // Place the drag caret to match the drop index
            NSArray *pageletControllers = [self pageletDOMControllers];
            if (dropIndex >= [pageletControllers count])
            {
                DOMNode *node = [[self sidebarDivElement] lastChild];
                DOMRange *range = [[node ownerDocument] createRange];
                [range setStartAfter:node];
                [[self webEditor] moveDragCaretToDOMRange:range];
                //[self moveDragCaretToAfterDOMNode:node];
            }
            else
            {
                WEKWebEditorItem *aPageletItem = [pageletControllers objectAtIndex:dropIndex];
                
                DOMRange *range = [[[aPageletItem HTMLElement] ownerDocument] createRange];
                [range setStartBefore:[aPageletItem HTMLElement]];
                [[self webEditor] moveDragCaretToDOMRange:range];
                //[self moveDragCaretToAfterDOMNode:[[aPageletItem HTMLElement] previousSibling]];
            }
        }
    }
    
    
    // Finish up
    if (!result)
    {
        [self draggingExited:dragInfo];
    }
    else if (!_drawAsDropTarget)
    {
        _drawAsDropTarget = YES;
        [self setNeedsDisplay];
    }
    
    return result;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender;
{
    [self setNeedsDisplay];
    _drawAsDropTarget = NO;
    
    [self removeDragCaret];
    [[self webEditor] removeDragCaret];
}

- (BOOL) prepareForDragOperation:(id <NSDraggingInfo>)sender;
{
    [self setNeedsDisplay];
    _drawAsDropTarget = NO;
    
    return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)dragInfo;
{
    NSUInteger dropIndex = [self indexOfDrop:dragInfo];
    if (dropIndex == NSNotFound) dropIndex = 0;
    
    
    BOOL result = NO;
    
    WEKWebEditorView *webEditor = [self webEditor];
    SVSidebarPageletsController *pageletsController = [self pageletsController];
    
    
    //  When dragging within the sidebar, want to move the selected pagelets
    if ([dragInfo draggingSource] == webEditor &&
        [dragInfo draggingSourceOperationMask] & NSDragOperationGeneric)
    {
        NSArray *sidebarPageletControllers = [self pageletDOMControllers];
        NSArray *graphicControllers = [[webEditor draggedItems] copy];
        
        for (SVDOMController *aPageletItem in graphicControllers)
        {
            if ([sidebarPageletControllers containsObjectIdenticalTo:aPageletItem])
            {
                result = YES;
                [webEditor forgetDraggedItems];
                
                SVGraphic *pagelet = [aPageletItem representedObject];
                [pageletsController
                 moveObject:pagelet toIndex:dropIndex];
            }
        }
        
        [graphicControllers release];
    }
    
    
    if (!result)
    {
        // Fallback to inserting a new pagelet from the pasteboard
        result = [pageletsController insertPageletsFromPasteboard:[dragInfo draggingPasteboard]
                                            atArrangedObjectIndex:dropIndex];
        
        
        if (result)
        {
            // Remove dragged items early since the WebView is about to refresh. If they came from an outside source has no effect
            if ([self dragOperation:dragInfo] == NSDragOperationGeneric)
            {
                [webEditor removeDraggedItems];
            }
            [webEditor didChangeText];  // -removeDraggedItems calls -shouldChangeText: etc. internally
        }
    }
    
    return result;
}

#pragma mark Drag Caret

- (void)removeDragCaret;
{
    // Schedule removal
    [[_dragCaret style] setHeight:@"0px"];
    
    [_dragCaret performSelector:@selector(ks_removeFromParentNode)
                     withObject:nil
                     afterDelay:0.25];
    
    [_dragCaret release]; _dragCaret = nil;
}

- (void)moveDragCaretToAfterDOMNode:(DOMNode *)node;
{
    // Do we actually need do anything?
    if (_dragCaret == node || [_dragCaret previousSibling] == node) return;
    
    
    [self removeDragCaret];
    
    OBASSERT(!_dragCaret);
    _dragCaret = [[[self HTMLElement] ownerDocument] createElement:@"div"];
    [_dragCaret retain];
    
    DOMCSSStyleDeclaration *style = [_dragCaret style];
    [style setWidth:@"100%"];
    [style setProperty:@"-webkit-transition-duration" value:@"0.25s" priority:@""];
    
    [[node parentNode] insertBefore:_dragCaret refChild:[node nextSibling]];
    [style setHeight:@"75px"];
}

#pragma mark Moving

- (void)tryToMovePagelet:(SVDOMController *)pagelet downToPosition:(CGPoint)position;
{
    NSArray *pagelets = [self pageletDOMControllers];
    NSUInteger index = [pagelets indexOfObjectIdenticalTo:pagelet]  + 1;
    
    CGPoint startPosition = [pagelet positionIgnoringRelativePosition];
    CGFloat gapAvailable = position.y - startPosition.y;
    if (index == 1 && gapAvailable < 0.0f) return;  // constrain to top of sidebar
    
    if (index < [pagelets count])
    {
        SVGraphicDOMController *nextPagelet = [pagelets objectAtIndex:index];
        if (2 * gapAvailable > [[nextPagelet HTMLElement] boundingBox].size.height)
        {
            // Make the swap
            [[self pageletsController] moveObject:[pagelet representedObject]
                                      afterObject:[nextPagelet representedObject]];
            
            // By calling back in, we should account for a drag that somehow covers multiple pagelets
            [self updateIfNeeded];
            [self tryToMovePagelet:pagelet downToPosition:position];
            return;
        }
    }
    else
    {
        // This is the last pagelet. Disallow dragging down
        if (position.y > startPosition.y) position = startPosition;
    }
    
    [pagelet moveToRelativePosition:CGPointMake(0.0f, position.y - startPosition.y)];
}

- (void)tryToMovePagelet:(SVDOMController *)pagelet upToPosition:(CGPoint)position;
{
    NSArray *pagelets = [self pageletDOMControllers];
    NSUInteger index = [pagelets indexOfObjectIdenticalTo:pagelet];
    
    CGPoint startPosition = [pagelet positionIgnoringRelativePosition];
    CGFloat gapAvailable = position.y - startPosition.y;
    if (index+1 >= [pagelets count] && gapAvailable > 0.0f) return;
        
    if (index > 0)
    {
        SVGraphicDOMController *previousPagelet = [pagelets objectAtIndex:index-1];
        if (2 * -gapAvailable > [[previousPagelet HTMLElement] boundingBox].size.height)
        {
            // Make the swap
            [[self pageletsController] moveObject:[pagelet representedObject]
                                     beforeObject:[previousPagelet representedObject]];
            
            // By calling back in, we should account for a drag that somehow covers multiple pagelets
            [self updateIfNeeded];
            [self tryToMovePagelet:pagelet upToPosition:position];
            return;
        }
    }
    else
    {
        // This is the last pagelet. Disallow dragging down
        if (position.y < startPosition.y) position = startPosition;
    }    
    
    [pagelet moveToRelativePosition:CGPointMake(0.0f, position.y - startPosition.y)];
}

- (void)moveGraphicWithDOMController:(SVDOMController *)graphicController
                          toPosition:(CGPoint)position
                               event:(NSEvent *)event;
{
    OBPRECONDITION(graphicController);
    
    
    // Do any of siblings fit into the available space?
    CGFloat delta = [event deltaY];
    if (delta < 0.0f)
    {
        [self tryToMovePagelet:graphicController upToPosition:position];
    }
    else if (delta > 0.0f)
    {
        [self tryToMovePagelet:graphicController downToPosition:position];
    }
}

- (void)moveObjectUp:(id)sender;
{
    [[self pageletsController] exchangeWithPrevious:sender];
}

- (void)moveObjectDown:(id)sender;
{
    [[self pageletsController] exchangeWithNext:sender];
}

#pragma mark Drawing

- (NSRect)dropTargetRect;
{
    NSRect result = [[self sidebarDivElement] boundingBox];
    return result;
}

- (NSRect)drawingRect;
{
    NSRect result = [super drawingRect];
    
    if (_drawAsDropTarget)
    {
        result = NSUnionRect(result, [self dropTargetRect]);
    }
    
    return result;
}

- (void)drawRect:(NSRect)dirtyRect inView:(NSView *)view;
{
    [super drawRect:dirtyRect inView:view];
    
    // Draw outline
    if (_drawAsDropTarget)
    {
        [[NSColor aquaColor] set];
        NSFrameRectWithWidth([self dropTargetRect], 2.0f);
    }
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == sSVSidebarDOMControllerPageletsObservation)
    {
        NSArray *loadedPagelets = [[self pageletDOMControllers] valueForKey:@"representedObject"];
        if (!loadedPagelets) loadedPagelets = [NSArray array];  // so comparing empty to equal works out
        
        if (![[object valueForKeyPath:keyPath] isEqual:loadedPagelets])
        {
            [self setNeedsUpdateWithSelector:@selector(updatePageletOrdering)];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end


#pragma mark -


@implementation WEKWebEditorItem (SVSidebarDOMController)

- (SVSidebarDOMController *)sidebarDOMController;
{
    return [[self parentWebEditorItem] sidebarDOMController];
}

@end



#pragma mark -


@implementation SVSidebar (SVSidebarDOMController)

- (SVDOMController *)newDOMController;
{
    return [[SVSidebarDOMController alloc] initWithRepresentedObject:self];
}

@end