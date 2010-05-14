//
//  WEKWebView.m
//  Sandvox
//
//  Created by Mike on 23/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "WEKWebView.h"
#import "WebEditingKit.h"

#import "DOMNode+Karelia.h"
#import "NSResponder+Karelia.h"


@implementation WEKWebView

- (WEKWebEditorView *)webEditor
{
    return (WEKWebEditorView *)[self superview];
}

@synthesize delegateWillHandleDraggingInfo = _delegateWillHandleDraggingInfo;

- (BOOL)isFirstResponder
{
    BOOL result = NO;
    
    NSResponder *firstResponder = [[self window] firstResponder];
    if ([firstResponder isKindOfClass:[NSView class]])
    {
        NSView *selectedView = (NSView *)firstResponder;
        result = [selectedView isDescendantOf:self];
    }
    
    return result;
}

#pragma mark Actions

- (IBAction)reload:(id)sender
{
    // Don't want to support this. Someone else will deal with it
    [self makeNextResponderDoCommandBySelector:_cmd];
}

#pragma mark Dragging Destination

- (void)willUpdateDrag:(id <NSDraggingInfo>)sender result:(NSDragOperation)result;
{
    // Update drag highlight to match
    DOMNode *dropNode = nil;
    if (result > NSDragOperationNone)
    {
        // Locate the DOM controller/item for the destination
        NSPoint point = [self convertPointFromBase:[sender draggingLocation]];
        DOMRange *editingRange = [self editableDOMRangeForPoint:point];
        
        if (editingRange)
        {
            WEKWebEditorItem <SVWebEditorText> *controller = [[[self webEditor] dataSource]
                                                              webEditor:[self webEditor]
                                                              textBlockForDOMRange:editingRange];
            
            
            // Ask the controller if it's sure of the drop
            [controller webEditorTextValidateDrop:sender proposedOperation:&result];
            
            
            // Controller's HTML element determines where to draw the drop highlight
            if (result > NSDragOperationNone) dropNode = [controller HTMLElement];
        }
    }
    [[self webEditor] moveDragHighlightToDOMNode:dropNode];
}

/*  Our aim here is to extend WebView to support some extra drag & drop methods that we'd prefer. Override everything to be sure we don't collide with WebKit in an unexpected manner.
 */

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    WEKWebEditorView *webEditor = [self webEditor];
    
    NSDragOperation result = [[webEditor draggingDestinationDelegate] draggingEntered:sender];
    if (result)
    {
        _delegateWillHandleDraggingInfo = YES;
        NSDragOperation superOp = [super draggingEntered:sender];
        
        if (superOp)
        {
            NSLog(@"Delegate expectd to handle drop, but WebView still did anyway");
            _delegateWillHandleDraggingInfo = NO;
            result = superOp;
        }
    }
    else
    {
        _delegateWillHandleDraggingInfo = NO;
        result = [super draggingEntered:sender];
    }
    
    
    [self willUpdateDrag:sender result:result];
    
    
    return result;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
    WEKWebEditorView *webEditor = [self webEditor];
    
    NSDragOperation result = [[webEditor draggingDestinationDelegate] draggingUpdated:sender];
    if (result)
    {
        // Pretend to WebView that dragging exited
        if (!_delegateWillHandleDraggingInfo) 
        {
            [super draggingExited:sender];
            _delegateWillHandleDraggingInfo = YES;
        }
    }
    else
    {
        _delegateWillHandleDraggingInfo = NO;
        
        [[self webEditor] performSelector:@selector(removeDragCaretFromDOMNodes)];
        [[self webEditor] moveDragHighlightToDOMNode:nil];
    
        result = [super draggingUpdated:sender];
    }
    
    
    [self willUpdateDrag:sender result:result];
    
    
    return result;
    
    
    
    // WebKit bug workaround: When dragging exits an editable area, although the cursor updates properly, the drag caret is not removed.
    // Maddeningly though, calling -removeDragCaret makes the WebView perform a Copy rather than Move op!
    //if (result == NSDragOperationNone) [self removeDragCaret];
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
    if (_delegateWillHandleDraggingInfo)
    {
        NSObject *delegate = [[self webEditor] draggingDestinationDelegate];
        if ([delegate respondsToSelector:_cmd]) [delegate draggingExited:sender];
    }
    [super draggingExited:sender];
    
    // Need to end any of our custom drawing
    //[[self webEditor] removeDragCaret];
    [[self webEditor] moveDragHighlightToDOMNode:nil];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    BOOL result;
    if (_delegateWillHandleDraggingInfo)
    {
        result = YES;
        NSObject *delegate = [[self webEditor] draggingDestinationDelegate];
        if ([delegate respondsToSelector:_cmd])
        {
            result = [delegate prepareForDragOperation:sender];
        }
    }
    else
    {
        result = [super prepareForDragOperation:sender];
    }
    
    
    // Need to end any of our custom drawing. Do NOT call -[WebView removeDragCaret] as it will forget where the drop is supposed to go!
    [[self webEditor] performSelector:@selector(removeDragCaretFromDOMNodes)];
    [[self webEditor] moveDragHighlightToDOMNode:nil];
    
    return result;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    if (_delegateWillHandleDraggingInfo)
    {
        NSObject *delegate = [[self webEditor] draggingDestinationDelegate];
        return [delegate performDragOperation:sender];
    }
    else
    {
        // Store pasteboard temporarily
        [[self webEditor] setValue:[sender draggingPasteboard] forKey:@"_insertionPasteboard"];
        BOOL result = [super performDragOperation:sender];
        [[self webEditor] setValue:nil forKey:@"_insertionPasteboard"];
        return result;
    }
}

@end

