//
//  SVWebEditorView+EditingSupport.m
//  Sandvox
//
//  Created by Mike on 15/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//


#import "SVWebEditorView.h"


@implementation SVWebEditorView (EditingSupport)

- (void)forwardCommandBySelector:(SEL)action;
{
    OBPRECONDITION(!_isForwardingCommandToWebView);
    _isForwardingCommandToWebView = YES;
    
    WebFrame *frame = [[self webView] selectedFrame];
    NSView *view = [[frame frameView] documentView];
    [view doCommandBySelector:action];
    
    _isForwardingCommandToWebView = NO;
}

#pragma mark Cut, Copy & Paste

- (void)cut:(id)sender
{
    if ([self copySelectedItemsToGeneralPasteboard])
    {
        [self delete:sender];
    }
}

- (void)copy:(id)sender
{
    [self copySelectedItemsToGeneralPasteboard];
}

- (BOOL)copySelectedItemsToGeneralPasteboard;
{
    // Rely on the datasource to serialize items to the pasteboard
    BOOL result = [[self dataSource] webEditor:self 
                                    writeItems:[self selectedItems]
                                  toPasteboard:[NSPasteboard generalPasteboard]];
    if (!result) NSBeep();
    
    return result;
}

- (void)delete:(id)sender forwardingSelector:(SEL)action;
{
    if ([self selectedDOMRange])
    {
        [self forwardCommandBySelector:action];
    }
    else
    {
        NSArray *items = [self selectedItems];
        if (![[self dataSource] webEditor:self deleteItems:items])
        {
            NSBeep();
        }
    }
}

- (void)delete:(id)sender;
{
    [self delete:sender forwardingSelector:_cmd];
}

- (void)deleteForward:(id)sender;
{
    [self delete:sender forwardingSelector:_cmd];
}

- (void)deleteBackward:(id)sender;
{
    [self delete:sender forwardingSelector:_cmd];
}

#pragma mark Undo

/*  Covers for private WebKit methods
 */

- (BOOL)allowsUndo { return [(NSTextView *)[self webView] allowsUndo]; }
- (void)setAllowsUndo:(BOOL)undo { [(NSTextView *)[self webView] setAllowsUndo:undo]; }

- (void)removeAllUndoActions
{
    [[self webView] performSelector:@selector(_clearUndoRedoOperations)];
}

@end
