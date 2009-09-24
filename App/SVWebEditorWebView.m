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
    // Alert the delegate to incoming drop
    [[self UIDelegate] webView:self willValidateDrop:sender];
    
    // Do usual thing, but give delegate final chance
    NSDragOperation result = [super draggingEntered:sender];
    if (result == NSDragOperationNone)
    {
        result = [[self UIDelegate] webView:self validateDrop:sender proposedOperation:result];
        _delegateWillHandleDrop = YES;
    }
    else
    {
        _delegateWillHandleDrop = NO;
    }
    
    return result;
}

- (NSDragOperation)draggingUpdated:(id < NSDraggingInfo >)sender
{
    // Alert the delegate to incoming drop
    [[self UIDelegate] webView:self willValidateDrop:sender];
    
    // Do usual thing, but give delegate final chance
    NSDragOperation result = [super draggingUpdated:sender];
    if (result == NSDragOperationNone)
    {
        result = [[self UIDelegate] webView:self validateDrop:sender proposedOperation:result];
        _delegateWillHandleDrop = YES;
    }
    else
    {
        _delegateWillHandleDrop = NO;
    }
    
    return result;
}

- (void)draggingEnded:(id < NSDraggingInfo >)sender
{
    _delegateWillHandleDrop = NO;
    
    if ([WebView instancesRespondToSelector:_cmd])  // shipping version of WebKit doesn't implement this method
    {
        [super draggingEnded:sender];
    }
}

- (void)draggingExited:(id < NSDraggingInfo >)sender
{
    _delegateWillHandleDrop = NO;
    [super draggingExited:sender];
}

- (BOOL)prepareForDragOperation:(id < NSDraggingInfo >)sender
{
    BOOL result = YES;
    if (!_delegateWillHandleDrop)
    {
        result = [super prepareForDragOperation:sender];
    }
    return result;
}

- (BOOL)performDragOperation:(id < NSDraggingInfo >)sender
{
    BOOL result;
    if (_delegateWillHandleDrop)
    {
        result = [[self UIDelegate] webView:self acceptDrop:sender];
    }
    else
    {
        result = [super performDragOperation:sender];
    }
    
    return result;
}

- (void)concludeDragOperation:(id < NSDraggingInfo >)sender
{
    if (!_delegateWillHandleDrop)
    {
        [super concludeDragOperation:sender];
    }
    _delegateWillHandleDrop = NO;
}

@end
