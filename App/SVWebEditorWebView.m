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
    
    // Do usual thing but let delegate have final say
    NSDragOperation result = [super draggingEntered:sender];
    result = [[self UIDelegate] webView:self validateDrop:sender proposedOperation:result];
    
    return result;
}

- (BOOL)wantsPeriodicDraggingUpdates { return NO; }

- (NSDragOperation)draggingUpdated:(id < NSDraggingInfo >)sender
{
    // Alert the delegate to incoming drop
    [[self UIDelegate] webView:self willValidateDrop:sender];
    
    // Do usual thing but let delegate have final say
    NSDragOperation result = [super draggingUpdated:sender];
    result = [[self UIDelegate] webView:self validateDrop:sender proposedOperation:result];
    
    return result;
}

- (void)draggingEnded:(id < NSDraggingInfo >)sender
{
    
}

- (void)draggingExited:(id < NSDraggingInfo >)sender
{
    
}

- (BOOL)prepareForDragOperation:(id < NSDraggingInfo >)sender
{
    return YES;
}

- (BOOL)performDragOperation:(id < NSDraggingInfo >)sender
{
    return YES;
}

- (void)concludeDragOperation:(id < NSDraggingInfo >)sender { }

@end
