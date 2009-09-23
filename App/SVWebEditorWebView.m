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
    return [self draggingUpdated:sender];
}

- (BOOL)wantsPeriodicDraggingUpdates { return NO; }

- (NSDragOperation)draggingUpdated:(id < NSDraggingInfo >)sender
{
    NSDragOperation result = [[self UIDelegate] webView:self validateDrop:sender];
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
