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

#pragma mark Dragging Destination

/*  Our aim here is to extend WebView to support some extra drag & drop methods that we'd prefer. Override everything to be sure we don't collide with WebKit in an unexpected manner.
 */

- (NSDragOperation)draggingEntered:(id < NSDraggingInfo >)sender
{
    sender = [[self webEditorView] willValidateDrop:sender];
    
    NSDragOperation result = [super draggingEntered:sender];
    result = [[self webEditorView] validateDrop:sender proposedOperation:result];
    
    return result;
}

- (NSDragOperation)draggingUpdated:(id < NSDraggingInfo >)sender
{
    sender = [[self webEditorView] willValidateDrop:sender];
    
    NSDragOperation result = [super draggingUpdated:sender];
    
    // WebKit bug workaround: When dragging exits an editable area, although the cursor updates properly, the drag caret is not removed
    if (result == NSDragOperationNone) [self removeDragCaret];
    
    result = [[self webEditorView] validateDrop:sender proposedOperation:result];
    return result;
}

- (void)draggingExited:(id < NSDraggingInfo >)sender
{
    [super draggingExited:sender];
    [[self webEditorView] removeDragHighlight];
}

- (void)concludeDragOperation:(id < NSDraggingInfo >)sender
{
    [super concludeDragOperation:sender];
    [[self webEditorView] removeDragHighlight];
}

@end

