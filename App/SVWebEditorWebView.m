//
//  SVWebEditorWebView.m
//  Sandvox
//
//  Created by Mike on 23/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorWebView.h"
#import "SVWebEditorView.h"

#import "DOMNode+Karelia.h"


@implementation SVWebEditorWebView

- (SVWebEditorView *)webEditorView
{
    return (SVWebEditorView *)[self superview];
}

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

#pragma mark Dragging Destination

/*  Our aim here is to extend WebView to support some extra drag & drop methods that we'd prefer. Override everything to be sure we don't collide with WebKit in an unexpected manner.
 */

- (NSDragOperation)draggingEntered:(id < NSDraggingInfo >)sender
{
    NSDragOperation result = [super draggingEntered:sender];
    _webEditorViewWillHandleDrop = [[self webEditorView] validateDrop:sender
                                                    proposedOperation:&result];
    
    return result;
}

- (NSDragOperation)draggingUpdated:(id < NSDraggingInfo >)sender
{
    NSDragOperation result = [super draggingUpdated:sender];
    
    // WebKit bug workaround: When dragging exits an editable area, although the cursor updates properly, the drag caret is not removed
    if (result == NSDragOperationNone) [self removeDragCaret];
    
    _webEditorViewWillHandleDrop = [[self webEditorView] validateDrop:sender
                                                    proposedOperation:&result];
    
    return result;
}

- (void)draggingExited:(id < NSDraggingInfo >)sender
{
    [super draggingExited:sender];
    
    // Need to end any of our custom drawing
    [[self webEditorView] removeDragCaret];
    [[self webEditorView] moveDragHighlightToDOMNode:nil];
}

- (BOOL)prepareForDragOperation:(id < NSDraggingInfo >)sender
{
    BOOL result = (_webEditorViewWillHandleDrop ? YES : [super prepareForDragOperation:sender]);
    
    // Need to end any of our custom drawing. Do NOT call -[WebView removeDragCaret] as it will forget where the drop is supposed to go!
    [[self webEditorView] performSelector:@selector(removeDragCaretFromDOMNodes)];
    [[self webEditorView] moveDragHighlightToDOMNode:nil];
    
    return result;
}

- (BOOL)performDragOperation:(id < NSDraggingInfo >)sender
{
    if (_webEditorViewWillHandleDrop)
    {
        return [[self webEditorView] acceptDrop:sender];
    }
    else
    {
        return [super performDragOperation:sender];
    }
}

@end

