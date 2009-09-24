//
//  SVWebEditorWebView.m
//  Sandvox
//
//  Created by Mike on 23/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorWebView.h"


@implementation SVWebEditorWebView

@dynamic UIDelegate;

/*  Our aim here is to extend WebUIDelegate to support some extra drag & drop methods that we'd prefer. Override everything to be sure we don't collide with WebKit in an unexpected manner.
 */

- (NSDragOperation)draggingEntered:(id < NSDraggingInfo >)sender
{
    NSDragOperation result = [super draggingEntered:sender];
    if (result == NSDragOperationNone && [[self superview] respondsToSelector:_cmd])
    {
        result = [[self superview] draggingEntered:sender];
        _superviewWillHandleDrop = YES;
    }
    else
    {
        _superviewWillHandleDrop = NO;
    }
    
    return result;
}

- (NSDragOperation)draggingUpdated:(id < NSDraggingInfo >)sender
{
    NSDragOperation result = [super draggingUpdated:sender];
    if (result == NSDragOperationNone && [[self superview] respondsToSelector:_cmd])
    {
        result = [[self superview] draggingUpdated:sender];
        _superviewWillHandleDrop = YES;
    }
    else
    {
        _superviewWillHandleDrop = NO;
    }
    
    return result;
}

- (void)draggingEnded:(id < NSDraggingInfo >)sender
{
    if (_superviewWillHandleDrop)
    {
        _superviewWillHandleDrop = NO;
        if ([[self superview] respondsToSelector:_cmd])
        {
            [[self superview] draggingEnded:sender];
        }
    }
    else
    {
        if ([WebView instancesRespondToSelector:_cmd])  // shipping version of WebKit doesn't implement this method
        {
            [super draggingEnded:sender];
        }
    }
}

- (void)draggingExited:(id < NSDraggingInfo >)sender
{
    if (_superviewWillHandleDrop)
    {
        _superviewWillHandleDrop = NO;
        if ([[self superview] respondsToSelector:_cmd])
        {
            [[self superview] draggingExited:sender];
        }
    }
    else
    {
        [super draggingExited:sender];
    }
}

- (BOOL)prepareForDragOperation:(id < NSDraggingInfo >)sender
{
    BOOL result = YES;
    
    if (_superviewWillHandleDrop)
    {
        if ([[self superview] respondsToSelector:_cmd])
        {
            result = [[self superview] prepareForDragOperation:sender];
        }
    }
    else
    {
        result = [super prepareForDragOperation:sender];
    }
    
    return result;
}

- (BOOL)performDragOperation:(id < NSDraggingInfo >)sender
{
    BOOL result = NO;
    
    if (_superviewWillHandleDrop)
    {
        if ([[self superview] respondsToSelector:_cmd])
        {
            result = [[self superview] performDragOperation:sender];
        }
    }
    else
    {
        result = [super performDragOperation:sender];
    }
    
    return result;
}

- (void)concludeDragOperation:(id < NSDraggingInfo >)sender
{
    if (_superviewWillHandleDrop)
    {
        _superviewWillHandleDrop = NO;
        if ([[self superview] respondsToSelector:_cmd])
        {
            [[self superview] concludeDragOperation:sender];
        }
    }
    else
    {
        [super concludeDragOperation:sender];
    }
}

@end
