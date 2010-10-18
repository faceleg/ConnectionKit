//
//  SVMediaDOMController.m
//  Sandvox
//
//  Created by Mike on 18/10/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMediaDOMController.h"

#import "SVPasteboardItemInternal.h"

#import "NSColor+Karelia.h"


@implementation SVMediaDOMController

#pragma mark Properties

// TODO: proper logic for this:
- (BOOL)isMediaPlaceholder; { return YES; }

#pragma mark Drag & Drop

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
{
    if ([self isMediaPlaceholder])
    {
        _drawAsDropTarget = YES;
        [self setNeedsDisplay];
        return NSDragOperationCopy;
    }
    
    return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender;
{
    [self setNeedsDisplay];
    _drawAsDropTarget = NO;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
{
    NSPasteboard *pboard = [sender draggingPasteboard];
    
    NSString *type = [pboard availableTypeFromArray:[SVMediaGraphic readableTypesForPasteboard:pboard]];
    if (type)
    {
        [[self representedObject] awakeFromPasteboardItem:pboard];
        return YES;
    }
    
    return NO;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;
{
    [self setNeedsDisplay];
    _drawAsDropTarget = NO;
}

- (NSArray *)registeredDraggedTypes;
{
    return [SVMediaGraphic readableTypesForPasteboard:nil];
}

- (NSRect)drawingRect;
{
    NSRect result = [super drawingRect];
    
    if (_drawAsDropTarget)
    {
        result = NSUnionRect(result, [[self HTMLElement] boundingBox]);
    }
    
    return result;
}

#pragma mark Drawing

- (void)drawRect:(NSRect)dirtyRect inView:(NSView *)view;
{
    [super drawRect:dirtyRect inView:view];
    
    // Draw outline
    if (_drawAsDropTarget)
    {
        [[NSColor aquaColor] set];
        NSFrameRectWithWidth([[self HTMLElement] boundingBox], 2.0f);
    }
}

@end
