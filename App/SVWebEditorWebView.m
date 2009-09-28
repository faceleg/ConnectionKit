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

@interface SVWebEditorWebView (Superview)
- (NSDragOperation)draggingEnteredSuperview:(id <NSDraggingInfo>)sender;
- (void)draggingExitedSuperview:(id <NSDraggingInfo>)sender;
@end


@implementation SVWebEditorWebView

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


/*  Our aim here is to extend WebView to support some extra drag & drop methods that we'd prefer. Override everything to be sure we don't collide with WebKit in an unexpected manner.
 */

- (NSDragOperation)draggingEntered:(id < NSDraggingInfo >)sender
{
    return [self validateDrop:sender];
}

- (NSDragOperation)draggingUpdated:(id < NSDraggingInfo >)sender
{
    return [self validateDrop:sender];
}

- (void)draggingExited:(id < NSDraggingInfo >)sender
{
    [self validateDrop:nil];
}

- (NSDragOperation)validateDrop:(id <NSDraggingInfo>)sender;
{
    DOMNode *dropNode = nil;
    
    if (sender)
    {
        NSPoint point = [self convertPointFromBase:[sender draggingLocation]];
        DOMRange *editingRange = [self editableDOMRangeForPoint:point];
        dropNode = [[editingRange startContainer] containingContentEditableElement];
    }
    
    
    NSDragOperation result = NSDragOperationNone;
    if (dropNode)
    {
        result = NSDragOperationCopy;
    }
    
    // Mark for redraw if needed
    if (dropNode != [self draggingDestinationNode]) [self setDraggingDestinationNode:dropNode];
        
    return result;
}

- (void)draggingEnded:(id < NSDraggingInfo >)sender
{
    [self validateDrop:nil];
}

@end