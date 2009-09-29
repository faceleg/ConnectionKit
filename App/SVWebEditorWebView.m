//
//  SVWebEditorWebView.m
//  Sandvox
//
//  Created by Mike on 23/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorWebView.h"

#import "DOMNode+Karelia.h"
#import "NSColor+Karelia.h"


@interface SVWebEditorWebView ()
@property(nonatomic, retain) DOMNode *draggingDestinationNode;
@end


@implementation SVWebEditorWebView

#pragma mark Drawing

- (void)didDrawRect:(NSRect)dirtyRect;
{
    // Draw drop overlay if there is one. 3px inset from bounding box, "Aqua" colour
    DOMNode *draggingDestinationNode = [self draggingDestinationNode];
    if (draggingDestinationNode)
    {
        NSRect dropRect = [draggingDestinationNode boundingBox];
        
        [[NSColor aquaColor] setFill];
        NSFrameRectWithWidth(dropRect, 3.0f);
    }
}

@synthesize draggingDestinationNode = _draggingDestinationNode;
- (void)setDraggingDestinationNode:(DOMNode *)node
{
    [_draggingDestinationNode setDocumentViewNeedsDisplayInBoundingBoxRect];
    
    [node retain];
    [_draggingDestinationNode release];
    _draggingDestinationNode = node;
    
    [node setDocumentViewNeedsDisplayInBoundingBoxRect];
}

#pragma mark Dragging Destination

/*  Our aim here is to extend WebView to support some extra drag & drop methods that we'd prefer. Override everything to be sure we don't collide with WebKit in an unexpected manner.
 */

- (NSDragOperation)draggingEntered:(id < NSDraggingInfo >)sender
{
    NSDragOperation result = [super draggingEntered:sender];
    [self viewDidValidate:result drop:sender];
    return result;
}

- (NSDragOperation)draggingUpdated:(id < NSDraggingInfo >)sender
{
    NSDragOperation result = [super draggingUpdated:sender];
    [self viewDidValidate:result drop:sender];
    return result;
}

- (void)draggingExited:(id < NSDraggingInfo >)sender
{
    [super draggingExited:sender];
    [self setDraggingDestinationNode:nil];
}

- (void)concludeDragOperation:(id < NSDraggingInfo >)sender
{
    [super concludeDragOperation:sender];
    [self setDraggingDestinationNode:nil];
}

- (void)viewDidValidate:(NSDragOperation)op drop:(id <NSDraggingInfo>)sender;
{
    OBPRECONDITION(sender);
    
    
    DOMNode *dropNode = nil;
    if (op > NSDragOperationNone)
    {
        NSPoint point = [self convertPointFromBase:[sender draggingLocation]];
        DOMRange *editingRange = [self editableDOMRangeForPoint:point];
        dropNode = [[editingRange startContainer] containingContentEditableElement];
    }
    
    
    // Mark for redraw if needed
    if (dropNode != [self draggingDestinationNode]) [self setDraggingDestinationNode:dropNode];
    
    
    // WebKit bug workaround: When dragging exits an editable area, although the cursor updates properly, the drag caret is not remoed
    if (op == NSDragOperationNone) [self removeDragCaret];
}

@end

