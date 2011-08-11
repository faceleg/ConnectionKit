//
//  WEKWebEditorView+Dragging.m
//  Sandvox
//
//  Created by Mike on 07/10/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//


#import "WEKWebEditorView.h"
#import "WEKWebEditorItem.h"

#import "DOMNode+Karelia.h"
#import "NSColor+Karelia.h"


#define WEKDragImageAlpha 0.50f // name & value copied from WebKit
#define WebMaxDragImageSize NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)    // was trying 200x200 before


@interface WEKWebEditorView (DraggingPrivate)

// Dragging destination
- (void)removeDragCaretFromDOMNodes;

@end


#pragma mark -


@implementation WEKWebEditorView (Dragging)

#pragma mark Drag Types

/*  All this sort of stuff we really want to target the webview with
 */

- (void)registerForDraggedTypes:(NSArray *)pboardTypes
{
    [[self webView] registerForDraggedTypes:pboardTypes];
}

- (NSArray *)registeredDraggedTypes
{
    return [[self webView] registeredDraggedTypes];
}

- (void)unregisterDraggedTypes
{
    [[self webView] unregisterDraggedTypes];
}

#pragma mark Dragging Destination

- (void)moveDragHighlightToDOMNode:(DOMNode *)node
{
    if (node != _dragHighlightNode)
    {
        NSView *view = [self documentView];
        
        if (_dragHighlightNode)
        {
            WEKWebEditorItem *item = [[self contentItem] hitTestDOMNode:_dragHighlightNode];
            [view setNeedsDisplayInRect:[item boundingBox]];
        //[_dragHighlightNode setDocumentViewNeedsDisplayInBoundingBoxRect];
        }
        
        [_dragHighlightNode release];   _dragHighlightNode = [node retain];
        
        if (node)
        {
            WEKWebEditorItem *item = [[self contentItem] hitTestDOMNode:node];
            [view setNeedsDisplayInRect:(item ? [item boundingBox] : [node boundingBox])];
        }
    }
}

- (void)moveDragCaretToDOMRange:(DOMRange *)range;
{
    OBPRECONDITION(range);
    OBPRECONDITION([range collapsed]);
    
    
    // Dump the old caret
    [self removeDragCaretFromDOMNodes];
    
    // Draw new one
    OBASSERT(!_dragCaretDOMRange);
    _dragCaretDOMRange = [range copy];
    
    [self setNeedsDisplayInRect:[self rectOfDragCaret]];
}

- (void)removeDragCaret;
{
    //[[self webView] removeDragCaret]; — see -[WEKWebView draggingUpdated:] for why
    [self removeDragCaretFromDOMNodes];
}

// Support method that ignores any drag caret in the webview
- (void)removeDragCaretFromDOMNodes;
{
    [self setNeedsDisplayInRect:[self rectOfDragCaret]];
    
    [_dragCaretDOMRange release], _dragCaretDOMRange = nil;
}

#pragma mark Dragging Source

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
    // Only support operations that all dragged items support.
    NSDragOperation result = NSDragOperationEvery;
    for (WEKWebEditorItem *anItem in [self draggedItems])
    {
        result = result & [anItem draggingSourceOperationMaskForLocal:isLocal];
    }
    
    return result;
}

- (void)draggedImage:(NSImage *)anImage beganAt:(NSPoint)aPoint
{
    // Store dragged items
    OBASSERT(!_draggedItems);
    _draggedItems = [[self selectedItems] copy];    // will redraw without selection borders
}

- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation;
{
    if (operation == NSDragOperationMove || operation == NSDragOperationDelete)
    {
        [self removeDraggedItems];
        [self didChangeText];
    }
    
    // Clean up
    [self forgetDraggedItems];
}

- (NSArray *)draggedItems; { return _draggedItems; }

- (void)removeDraggedItems; // removes from DOM and item tree
{
    if ([self draggedItems])
    {
        // Remove the objects
        [[self dataSource] webEditor:self removeItems:[self draggedItems]];
        
        // Clean up
        [self forgetDraggedItems];
    }
    
    /*  This code is responsible for #118306. Pretty sure we don't need it since all drags are now handled entirely by webkit, or by moving the item. No more hybrid system.
     
    else if (selection = [self selectedDOMRange])
    {
        // The drag was initiated by WebView itself, so make it delete the dragged items
        // -shouldChangeTextInDOMRange: is needed since -delete: doesn't do so itself for some reason
        if ([self shouldChangeTextInDOMRange:selection])
        {
            [[self webView] delete:self];
        }
    }*/
}

- (void)forgetDraggedItems; // call if you want to take over handling of drag source
{
    // Ditch the items
    [_draggedItems release]; _draggedItems = nil;
}

#pragma mark Drawing

- (void)drawDragCaretInView:(NSView *)view;
{
    if (_dragCaretDOMRange)
    {
        [[NSColor aquaColor] set];
        NSRect drawingRect = [view convertRect:[self rectOfDragCaret] fromView:self];
        NSRect outlineRect = NSInsetRect(drawingRect, 0.0f, 1.0f);
        NSEraseRect(outlineRect);
        NSRectFill(NSInsetRect(outlineRect, 0.0f, 1.0f));
    }
}

#pragma mark Layout

/*  These 2 methods should one day probably be additions to DOMNode
 */

- (DOMNode *)_previousVisibleSibling:(DOMNode *)node
{
    DOMNode *result = node;
    while (result)
    {
        if (NSIsEmptyRect([result boundingBox]))
        {
            result = [result previousSibling];
        }
        else
        {
            break;
        }
    }
    
    return result;
}

- (DOMNode *)_nextVisibleSibling:(DOMNode *)node
{
    DOMNode *result = node;
    while (result)
    {
        if (NSIsEmptyRect([result boundingBox]))
        {
            result = [result nextSibling];
        }
        else
        {
            break;
        }
    }
    
    return result;
}


- (NSRect)rectOfDragCaret;
{
    DOMNodeList *childNodes = [[_dragCaretDOMRange startContainer] childNodes];
    
    
    //  Try to place between the 2 visible nodes
    DOMNode *node1 = [self _previousVisibleSibling:[childNodes item:([_dragCaretDOMRange startOffset] - 1)]];
    DOMNode *node2 = [self _previousVisibleSibling:[childNodes item:[_dragCaretDOMRange startOffset]]];
    
    NSRect box1 = [node1 boundingBox];
    NSRect box2 = [node2 boundingBox];
    
    
    //  If they don't both exist, have to tweak drawing model
    NSRect result;
    if (node1 && node2)
    {
        result.origin.x = MIN(NSMinX(box1), NSMinX(box2));
        result.origin.y = NSMaxY(box1);
        result.size.width = MAX(NSMaxX(box1), NSMaxX(box2)) - result.origin.x;
        result.size.height = NSMinY(box2) - result.origin.y;
    }
    else if (node1)
    {
        result = box1;  result.origin.y += result.size.height,  result.size.height = 0.0f;
    }
    else if (node2)
    {
        result = box2;  result.size.height = 0.0f;
    }
    else
    {
        result = [[_dragCaretDOMRange startContainer] boundingBox];
        result.size.height = 0.0f;
    }
    
    
    // It should be at least 7 pixels tall
    if (result.size.height < 7.0)
    {
        result = NSInsetRect(result, 0.0f, -0.5 * (7.0 - result.size.height));
    }
    
    
    return [self convertRect:result fromView:[[_dragCaretDOMRange commonAncestorContainer] documentView]];
}

@end


#pragma mark -


@implementation NSView (WEKWebEditorViewExtras)

- (void)dragImageForItem:(WEKWebEditorItem *)item
                   event:(NSEvent *)event
              pasteboard:(NSPasteboard *)pasteboard 
                  source:(id)source;
{
    NSPoint mouseDownPoint = [self convertPoint:[event locationInWindow] fromView:nil];
    NSImage *dragImage;
    NSPoint origin;
    
    DOMElement *element = [item HTMLElement];
    NSImage *image = [element performSelector:@selector(renderedImage)];
    if (!image) image = [element image];
//    if (!image);    could fallback to snapshotting view here
    
    NSRect rect = [element boundingBox];
    NSSize originalSize = rect.size;
    origin = rect.origin;
    
    dragImage = [[image copy] autorelease];
    [dragImage setScalesWhenResized:YES];
    [dragImage setSize:originalSize];
    
    
    // Scale down to fit 200px box, making semi-transparent in the process
    NSSize newSize = originalSize;
    if (newSize.width > WebMaxDragImageSize.width || newSize.height > WebMaxDragImageSize.height)
    {
        if (newSize.height > newSize.width)
        {
            newSize.width = newSize.width * (WebMaxDragImageSize.height / newSize.height);
            newSize.height = WebMaxDragImageSize.height;
        }
        else
        {
            newSize.height = newSize.height * (WebMaxDragImageSize.width / newSize.width);
            newSize.width = WebMaxDragImageSize.width;
        }
    }
    
    
    // Get ready to draw
    NSSize imgSize = newSize;
    imgSize.height += 2.0f; imgSize.width += 2.0f;    // expand by 1px to capture border
    NSImage *result = [[[NSImage alloc] initWithSize:imgSize] autorelease];
    
    [result lockFocus];
    
    
    // Draw the image
    [image drawInRect:NSMakeRect(1.0f, 1.0f, newSize.width, newSize.height)        
             fromRect:NSZeroRect
            operation:NSCompositeCopy
             fraction:WEKDragImageAlpha];
    
    
    // Draw image border
    NSRect drawingRect; drawingRect.origin = NSZeroPoint; drawingRect.size = imgSize;
    [[[NSColor grayColor] colorWithAlphaComponent:WEKDragImageAlpha] setFill];
    NSFrameRect(drawingRect);
    
    
    // Finish drawing
    [result unlockFocus];
    dragImage = result;
    
    
    // Start the drag
    // Properly orient the drag image and orient it differently if it's smaller than the original
    origin.x = mouseDownPoint.x - (((mouseDownPoint.x - origin.x) / originalSize.width) * newSize.width);
    origin.y = origin.y + originalSize.height;
    origin.y = mouseDownPoint.y - (((mouseDownPoint.y - origin.y) / originalSize.height) * newSize.height);
    
    [self dragImage:dragImage at:origin offset:NSZeroSize event:event pasteboard:pasteboard source:source slideBack:YES];
}

@end
