//
//  SVWebEditorView+Dragging.m
//  Sandvox
//
//  Created by Mike on 07/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//


#import "SVWebEditorView.h"
#import "SVWebEditorItem.h"

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

- (BOOL)validateDrop:(id <NSDraggingInfo>)sender proposedOperation:(NSDragOperation *)proposedOperation;
{
    BOOL result = NO;
    NSDragOperation op = *proposedOperation;
    
    
    // Update drag highlight to match
    DOMNode *dropNode = nil;
    if (op > NSDragOperationNone)
    {
        // Locate the DOM controller/item for the destination
        NSPoint point = [self convertPointFromBase:[sender draggingLocation]];
        DOMRange *editingRange = [[self webView] editableDOMRangeForPoint:point];
        
        SVWebEditorItem <SVWebEditorText> *controller =
        [[self dataSource] webEditor:self textBlockForDOMRange:editingRange];
        
        
        // Ask the controller if it's sure of the drop
        result = [controller webEditorTextValidateDrop:sender proposedOperation:&op];
        
              
        // Controller's HTML element determines where to draw the drop highlight
        if (op > NSDragOperationNone) dropNode = [controller HTMLElement];
        [self removeDragCaretFromDOMNodes]; // if not accepting drop, can't use our custom caret
    }
    [self moveDragHighlightToDOMNode:dropNode];
    
    
    // Let datasource have a crack at the drop. If it's not interested either, ensure the drag caret is removed
    if (op == NSDragOperationNone)
    {
        NSObject *draggingDestination = [[self dataSource] webEditor:self dragDestinationForDraggingInfo:sender];
        if (draggingDestination) op = [draggingDestination draggingUpdated:sender];
        
        if (op == NSDragOperationNone)
        {
            [self removeDragCaret];
        }
        else
        {
            result = YES;
        }
    }
    
    
    // Finish up
    *proposedOperation = op;
    return result;
}

- (BOOL)acceptDrop:(id <NSDraggingInfo>)sender;
{
    //  Just make the datasource do the work
    return [[self dataSource] webEditor:self acceptDrop:sender];
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

- (void)moveDragCaretToDOMRange:(DOMRange *)range;
{
    OBPRECONDITION(range);
    OBPRECONDITION([range collapsed]);
    
    
    // Dump the old caret
    [self removeDragCaret];
    
    // Draw new one
    OBASSERT(!_dragCaretDOMRange);
    _dragCaretDOMRange = [range copy];
    
    [self setNeedsDisplayInRect:[self rectOfDragCaret]];
}

- (void)removeDragCaret;
{
    //[[self webView] removeDragCaret]; — see -[SVWebEditorWebView draggingUpdated:] for why
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
    OBASSERT(!_draggedItems);
    _draggedItems = [[self selectedItems] copy];    // will redraw without selection borders
}

- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation;
{
    if (operation == NSDragOperationMove || operation == NSDragOperationDelete)
    {
        [self willChange];
        for (SVWebEditorItem *anItem in [self draggedItems])
        {
            // When moving an item within text, delete the source. Have to tell the rest of the system that we did this
            if ([[anItem HTMLElement] isContentEditable])
            {
                DOMHTMLElement *node = [anItem HTMLElement];
                [[node parentNode] removeChild:node];
                
                [anItem removeFromParentWebEditorItem];
            }
        }
        [self didChange];
        
        
        // Remove the objects
        [[self dataSource] webEditor:self deleteItems:[self draggedItems]];
    }
    
    // Clean up
    [_draggedItems release]; _draggedItems = nil;
}

- (NSArray *)draggedItems; { return _draggedItems; }

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
- (NSImage *)dragImageForSelectionFromItem:(SVWebEditorItem *)item
                                  location:(NSPoint *)outImageLocation
{
    // The core items involved
    DOMElement *element = [item HTMLElement];
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
    
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
    
    
    NSArray *types = [[self webView] pasteboardTypesForSelection];
    [pboard declareTypes:types owner:self];
    [[self webView] writeSelectionWithPasteboardTypes:types toPasteboard:pboard];
    
    
    if ([[self dataSource] webEditor:self addSelectionToPasteboard:pboard])
    {
        
        // Now let's start a-dragging!
        SVWebEditorItem *item = [self selectedItem]; // FIXME: use the item actually being dragged
        
        NSPoint dragImageRect;
        NSImage *dragImage = [self dragImageForSelectionFromItem:item location:&dragImageRect];
        
        if (dragImage)
        {
            // Moving an item is a 2 step process. Have to group the undo ops to make them appear as 1.
            NSUndoManager *undoManager = [self undoManager];
            [undoManager beginUndoGrouping];
            
            [self dragImage:dragImage
                         at:dragImageRect
                     offset:NSZeroSize
                      event:_mouseDownEvent
                 pasteboard:pboard
                     source:self
                  slideBack:YES];
            
            [undoManager endUndoGrouping]; 
        }
    }
    
    
    // A drag of the mouse automatically removes the possibility that editing might commence
    [_mouseDownEvent release],  _mouseDownEvent = nil;
}

@end
