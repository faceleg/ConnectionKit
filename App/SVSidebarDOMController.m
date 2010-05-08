//
//  SVSidebarDOMController.m
//  Sandvox
//
//  Created by Mike on 07/05/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVSidebarDOMController.h"
#import "SVSidebar.h"

#import "SVWebEditorView.h"

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

- (void)dealloc;
{
    [_sidebarDiv release];
    [super dealloc];
}

@synthesize sidebarDivElement = _sidebarDiv;

- (void)loadHTMLElementFromDocument:(DOMDocument *)document;
{
    [super loadHTMLElementFromDocument:document];
    
    // Also seek out sidebar div
    [self setSidebarDivElement:[document getElementById:@"sidebar"]];
}

#pragma mark Drop

/*  Similar to NSTableView's concept of dropping above a given row
 */
- (NSUInteger)indexOfDrop:(id <NSDraggingInfo>)dragInfo;
{
    NSUInteger result = NSNotFound;
    NSView *view = [[self HTMLElement] documentView];
    NSArray *pageletControllers = [self childWebEditorItems];
    NSPoint location = [view convertPointFromBase:[dragInfo draggingLocation]];
    
    
    // Ideally, we're making a drop *before* a pagelet
    SVWebEditorItem *previousItem = nil;
    NSUInteger i, count = [pageletControllers count];
    for (i = 0; i < count; i++)
    {
        // Calculate drop zone
        SVWebEditorItem *anItem = [pageletControllers objectAtIndex:i];
        
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

#pragma mark Drag & Drop

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)dragInfo;
{
    NSDragOperation result = NSDragOperationNone;
    
    NSUInteger dropIndex = [self indexOfDrop:dragInfo];
    if (dropIndex != NSNotFound)
    {
        NSDragOperation mask = [dragInfo draggingSourceOperationMask];
        result = mask & NSDragOperationMove;
        if (!result) result = mask & NSDragOperationCopy;
        
        
        if (result)
        {
            // Place the drag caret to match the drop index
            NSArray *pageletControllers = [self childWebEditorItems];
            if (dropIndex >= [pageletControllers count])
            {
                DOMNode *node = [[self sidebarDivElement] lastChild];
                DOMRange *range = [[node ownerDocument] createRange];
                [range setStartAfter:node];
                [[self webEditor] moveDragCaretToDOMRange:range];
                //[sidebarController moveDragCaretToAfterDOMNode:node];
            }
            else
            {
                SVWebEditorItem *aPageletItem = [pageletControllers objectAtIndex:dropIndex];
                
                DOMRange *range = [[[aPageletItem HTMLElement] ownerDocument] createRange];
                [range setStartBefore:[aPageletItem HTMLElement]];
                [[self webEditor] moveDragCaretToDOMRange:range];
                //[sidebarController moveDragCaretToAfterDOMNode:[[aPageletItem HTMLElement] previousSibling]];
            }
        }
    }
    
    
    // Finish up
    if (!result)
    {
        [self removeDragCaret];
    }
    
    return result;
}

- (SVWebEditorItem *)hitTestDOMNode:(DOMNode *)node draggingInfo:(id <NSDraggingInfo>)info;
{
    SVWebEditorItem *result = [super hitTestDOMNode:node draggingInfo:info];
    
    // No-one else wants it? Maybe we do!
    if (!result)
    {
        if ([self indexOfDrop:info] != NSNotFound) result = self;
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
    _dragCaret = [[[self webEditor] HTMLDocument] createElement:@"div"];
    [_dragCaret retain];
    
    DOMCSSStyleDeclaration *style = [_dragCaret style];
    [style setWidth:@"100%"];
    [style setProperty:@"-webkit-transition-duration" value:@"0.25s" priority:@""];
    
    [[node parentNode] insertBefore:_dragCaret refChild:[node nextSibling]];
    [style setHeight:@"75px"];
}

@end


#pragma mark -


@implementation SVSidebar (SVSidebarDOMController)

- (Class)DOMControllerClass;
{
    return [SVSidebarDOMController class];
}

@end