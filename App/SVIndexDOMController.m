//
//  SVIndexDOMController.m
//  Sandvox
//
//  Created by Mike on 19/10/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVIndexDOMController.h"

#import "SVGraphicFactory.h"
#import "SVPlugInGraphic.h"
#import "SVPagesController.h"

#import "NSColor+Karelia.h"


@implementation SVIndexDOMController

- (NSArray *)registeredDraggedTypes
{
    return [SVGraphicFactory graphicPasteboardTypes];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
{
    _drawAsDropTarget = YES;
    [self setNeedsDisplay];
    
    return NSDragOperationCopy;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender;
{
    [self setNeedsDisplay];
    _drawAsDropTarget = NO;
}

- (BOOL) prepareForDragOperation:(id <NSDraggingInfo>)sender;
{
    [self setNeedsDisplay];
    _drawAsDropTarget = NO;
    
    return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
{
    // Add pages to the collection, corresponding to media
    KTPage *collection = (KTPage *)[(SVIndexPlugIn *)[[self representedObject] plugIn] indexedCollection];
    
    SVPagesController *controller = [[SVPagesController alloc] init];
    [controller setManagedObjectContext:[collection managedObjectContext]];
    
    BOOL result = [controller addObjectsFromPasteboard:[sender draggingPasteboard]
                                          toCollection:collection];
    
    [controller release];
    return result;
}

#pragma mark Updating

// Updating should be handled by parent. I wish I could remember why this isn't the default
- (void)setNeedsUpdate; { [[self parentWebEditorItem] setNeedsUpdate]; }

#pragma mark Drawing

- (NSRect)dropTargetRect;
{
    NSRect result = [[self HTMLElement] boundingBox];
    
    // Movies draw using Core Animation so sit above any custom drawing of our own. Workaround by outsetting the rect
    NSString *tagName = [[self HTMLElement] tagName];
    if ([tagName isEqualToString:@"VIDEO"] || [tagName isEqualToString:@"OBJECT"])
    {
        result = NSInsetRect(result, -2.0f, -2.0f);
    }
    
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

@end
