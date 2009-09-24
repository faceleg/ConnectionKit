//
//  SVWebEditorWebView.m
//  Sandvox
//
//  Created by Mike on 23/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorWebView.h"


@interface SVWebEditorWebView (Superview)
- (NSDragOperation)draggingEnteredSuperview:(id <NSDraggingInfo>)sender;
- (void)draggingExitedSuperview:(id <NSDraggingInfo>)sender;
@end


@implementation SVWebEditorWebView

/*  Our aim here is to extend WebView to support some extra drag & drop methods that we'd prefer. Override everything to be sure we don't collide with WebKit in an unexpected manner.
 */

- (NSDragOperation)draggingEntered:(id < NSDraggingInfo >)sender
{
    NSDragOperation result = [super draggingEntered:sender];
    if (result == NSDragOperationNone)
    {
        result = [self draggingEnteredSuperview:sender];
    }
    else if (_superviewWillHandleDrop)
    {
        // Great, WebKit will handle the drop. But we need to inform previous target that it's gone
        [self draggingExitedSuperview:sender];
    }
    
    return result;
}

- (NSDragOperation)draggingUpdated:(id < NSDraggingInfo >)sender
{
    NSDragOperation result = [super draggingUpdated:sender];
    if (result == NSDragOperationNone)
    {
        // Although the drag has been updated from AppKit's perspective, to our superview, it may have only just entered
        if (!_superviewWillHandleDrop)
        {
            result = [self draggingEnteredSuperview:sender];
        }
        
        // Update drag
        if ([[self superview] respondsToSelector:_cmd])
        {
            result = [[self superview] draggingUpdated:sender];
        }
    }
    else if (_superviewWillHandleDrop)
    {
        // Great, WebKit will handle the drop. But we need to inform previous target that it's gone
        [self draggingExitedSuperview:sender];
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
        [self draggingExitedSuperview:sender];
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


@implementation SVWebEditorWebView (Superview)

- (NSDragOperation)draggingEnteredSuperview:(id <NSDraggingInfo>)sender;
{
    NSDragOperation result = NSDragOperationNone;
    
    if ([[self superview] respondsToSelector:@selector(draggingEntered:)])
    {
        result = [[self superview] draggingEntered:sender];
    }
    _superviewWillHandleDrop = YES;
    
    return result;
}

- (void)draggingExitedSuperview:(id <NSDraggingInfo>)sender
{
    _superviewWillHandleDrop = NO;
    if ([[self superview] respondsToSelector:@selector(draggingExited:)])
    {
        [[self superview] draggingExited:sender];
    }
}

@end

