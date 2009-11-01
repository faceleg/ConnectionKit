//
//  SVWebEditorView+Dragging.m
//  Sandvox
//
//  Created by Mike on 07/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//


#import "SVWebEditorView.h"

#import "DOMNode+Karelia.h"
#import "NSColor+Karelia.h"


#define WebDragImageAlpha 0.5f // name is copied from WebKit, but we use 0.5 instead of 0.75 which I felt obscured destination too much


@interface SVWebEditorView (DraggingPrivate)

// Dragging destination
- (void)removeDragCaretFromDOMNodes;

@end


#pragma mark -


@implementation SVWebEditorView (Dragging)

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

- (NSDragOperation)validateDrop:(id <NSDraggingInfo>)sender proposedOperation:(NSDragOperation)op;
{
    // Update drag highlight to match
    DOMNode *dropNode = nil;
    if (op > NSDragOperationNone)
    {
        NSPoint point = [self convertPointFromBase:[sender draggingLocation]];
        DOMRange *editingRange = [[self webView] editableDOMRangeForPoint:point];
        dropNode = [[editingRange startContainer] containingContentEditableElement];
        
        [self removeDragCaretFromDOMNodes]; // if WebView is accepting drop, can't use our custom caret
    }
    [self moveDragHighlightToDOMNode:dropNode];
    
    
    // Let datasource have a crack at the drop. If it's not interested either, ensure the drag caret is removed
    if (op == NSDragOperationNone)
    {
        op = [[self dataSource] webEditorView:self dataSourceShouldHandleDrop:sender];
        if (op == NSDragOperationNone) [self removeDragCaret];
    }
    
    
    return op;
}

- (void)moveDragHighlightToDOMNode:(DOMNode *)node
{
    if (node != _dragHighlightNode)
    {
        [_dragHighlightNode setDocumentViewNeedsDisplayInBoundingBoxRect];
        [_dragHighlightNode release];   _dragHighlightNode = [node retain];
        [node setDocumentViewNeedsDisplayInBoundingBoxRect];
    }
}

- (void)moveDragCaretToBeforeDOMNode:(DOMNode *)node;
{
    // Dump the old caret
    [self removeDragCaret];
    
    // Draw new one
    OBASSERT(!_dragCaretDOMRange);
    _dragCaretDOMRange = [[[node ownerDocument] createRange] retain];
    [_dragCaretDOMRange setStartBefore:node];
    [_dragCaretDOMRange collapse:YES];
    
    [self setNeedsDisplayInRect:[self rectOfDragCaret]];
}

- (void)moveDragCaretToAfterDOMNode:(DOMNode *)node;
{
    // Dump the old caret
    [self removeDragCaret];
    
    // Draw new one
    OBASSERT(!_dragCaretDOMRange);
    _dragCaretDOMRange = [[[node ownerDocument] createRange] retain];
    [_dragCaretDOMRange setStartAfter:node];
    [_dragCaretDOMRange collapse:YES];
    
    [self setNeedsDisplayInRect:[self rectOfDragCaret]];
}

- (void)removeDragCaret;
{
    [[self webView] removeDragCaret];
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
    NSDragOperation result = NSDragOperationCopy;
    if (isLocal) result = (result | NSDragOperationMove);
    return result;
}

- (void)draggedImage:(NSImage *)anImage beganAt:(NSPoint)aPoint
{
    // Hide the dragged items so it looks like a proper drag
    _isDragging = YES;    // will redraw without selection borders
}

- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation
{
    // Make the dragged items visible again
    _isDragging = NO;
    
    for (id <SVWebEditorItem> anItem in [self selectedItems])
    {
        DOMElement *element = [anItem DOMElement];
        [[element style] removeProperty:@"visibility"];
    }
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

/*  When beginning a drag, you want to drag all the selected items. I haven't quite decided how to do this yet – one big image containing them all or an image for the item under the mouse and a numeric overlay? – so this is fairly temporary. Also return by reference the origin of the image within our own coordinate system.
 */
- (NSImage *)dragImageForSelectionFromItem:(id <SVWebEditorItem>)item
                                  location:(NSPoint *)outImageLocation
{
    // The core items involved
    DOMElement *element = [item DOMElement];
    NSRect itemRect = NSInsetRect([element boundingBox], -1.0f, -1.0f);  // Expand by 1px to capture border
    NSImage *result = [[[NSImage alloc] initWithSize:itemRect.size] autorelease];
    
    WebFrameView *frameView = [[[element ownerDocument] webFrame] frameView];
    NSView <WebDocumentView> *docView = [frameView documentView];
    
    
    // Try to capture straight from WebKit. This is a private method so may not always be available
    if ([element respondsToSelector:@selector(renderedImage)])
    {
        NSImage *elementImage = [element performSelector:@selector(renderedImage)];
        if (elementImage)
        {
            NSRect drawingRect; drawingRect.origin = NSZeroPoint;   drawingRect.size = [elementImage size];
            
            [result lockFocus];
            
            [elementImage drawInRect:NSInsetRect(drawingRect, 1.0f, 1.0f)
                            fromRect:NSZeroRect
                           operation:NSCompositeCopy
                            fraction:WebDragImageAlpha];
            
            [[[NSColor grayColor] colorWithAlphaComponent:WebDragImageAlpha] setFill];
            NSFrameRect(drawingRect);
            
            [result unlockFocus];
        }
    }
    
    
    // Otherwise, fall back to caching display. Don't forget to be semi-transparent!
    if (!result)
    {
        NSRect imageDrawingRect = [frameView convertRect:itemRect fromView:docView];
        NSBitmapImageRep *bitmap = [frameView bitmapImageRepForCachingDisplayInRect:imageDrawingRect];
        [frameView cacheDisplayInRect:imageDrawingRect toBitmapImageRep:bitmap];
        
        NSImage *image = [[NSImage alloc] initWithSize:itemRect.size];
        [image addRepresentation:bitmap];
        
        [result lockFocus];
        [image drawAtPoint:NSZeroPoint
                  fromRect:NSZeroRect
                 operation:NSCompositeCopy
                  fraction:WebDragImageAlpha];
        [result unlockFocus];
        
        [image release];
    }
    
    
    // Also return rect if requested
    if (result && outImageLocation)
    {
        NSRect imageRect = [self convertRect:itemRect fromView:docView];
        *outImageLocation = imageRect.origin;
    }
    
    
    return result;
}

#pragma mark Layout

- (NSRect)rectOfDragCaret;
{
    DOMNodeList *childNodes = [[_dragCaretDOMRange startContainer] childNodes];
    DOMNode *node1 = [childNodes item:([_dragCaretDOMRange startOffset] - 1)];
    DOMNode *node2 = [childNodes item:[_dragCaretDOMRange startOffset]];
    
    NSRect box1 = [node1 boundingBox];
    NSRect box2 = [node2 boundingBox];
    
    // Claim the space between the pagelets
    NSRect result;
    result.origin.x = MIN(NSMinX(box1), NSMinX(box2));
    result.origin.y = NSMaxY(box1);
    result.size.width = MAX(NSMaxX(box1), NSMaxX(box2)) - result.origin.x;
    result.size.height = NSMinY(box2) - result.origin.y;
    
    // It should be at least 7 pixels tall
    if (result.size.height < 7.0)
    {
        result = NSInsetRect(result, 0.0f, -0.5 * (7.0 - result.size.height));
    }
    
    return [self convertRect:result fromView:[node1 documentView]];
}

#pragma mark Tracking the Mouse

- (void)mouseDragged:(NSEvent *)theEvent
{
    if (!_mouseDownEvent) return;   // otherwise we initiate a drag multiple times!
    
    
    
    
    //  Ideally, we'd place onto the pasteboard:
    //      Sandvox item info, everything, else, WebKit, does, normally
    //
    //  -[WebView writeElement:withPasteboardTypes:toPasteboard:] would seem to be ideal for this, but it turns out internally to fall back to trying to write the selection to the pasteboard, which is definitely not what we want. Fortunately, it boils down to writing:
    //      Sandvox item info, WebArchive, RTF, plain text
    //
    //  Furthermore, there arises the question of how to handle multiple items selected. WebKit has no concept of such a selection so couldn't help us here, even if it wanted to. Should we try to string together the HTML/text sections into one big lump? Or use 10.6's ability to write multiple items to the pasteboard?
    
    NSArray *selection = [self selectedItems];
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
    
    if ([[self dataSource] webEditorView:self writeItems:selection toPasteboard:pboard])
    {
        // Now let's start a-dragging!
        id <SVWebEditorItem> item = [selection lastObject]; // FIXME: use the item actually being dragged
        
        NSPoint dragImageRect;
        NSImage *dragImage = [self dragImageForSelectionFromItem:item location:&dragImageRect];
        
        if (dragImage)
        {
            [self dragImage:dragImage
                         at:dragImageRect
                     offset:NSZeroSize
                      event:_mouseDownEvent
                 pasteboard:pboard
                     source:self
                  slideBack:YES];
        }
    }
    
    
    // A drag of the mouse automatically removes the possibility that editing might commence
    [_mouseDownEvent release],  _mouseDownEvent = nil;
}

@end
