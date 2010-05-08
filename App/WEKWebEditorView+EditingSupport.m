//
//  WEKWebEditorView+EditingSupport.m
//  Sandvox
//
//  Created by Mike on 15/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//


#import "WEKWebEditorView.h"

#import "SVLinkInspector.h"


@interface SVValidatedUserInterfaceItem : NSObject <NSValidatedUserInterfaceItem>
{
  @private
    SEL         _action;
    NSInteger   _tag;
}

@property(nonatomic) SEL action;
@property(nonatomic) NSInteger tag;

@end


#pragma mark -


@implementation WEKWebEditorView (EditingSupport)

#pragma mark Cut, Copy & Paste

- (void)cut:(id)sender
{
    // Let the WebView handle it unless there is no text selection
    if ([self selectedDOMRange])
    {
        [self forceWebViewToPerform:_cmd withObject:sender];
    }
    else
    {
        if ([self copySelectedItemsToGeneralPasteboard])
        {
            [self delete:sender];
        }
    }
}

- (void)copy:(id)sender
{
    // Let the WebView handle it unless there is no text selection
    if ([self selectedDOMRange])
    {
        [self forceWebViewToPerform:_cmd withObject:sender];
    }
    else
    {
        [self copySelectedItemsToGeneralPasteboard];
    }
}

- (BOOL)copySelectedItemsToGeneralPasteboard;
{
    // Rely on the datasource to serialize items to the pasteboard
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard declareTypes:nil owner:nil];
    
    BOOL result = [[self dataSource] webEditor:self addSelectionToPasteboard:pasteboard];
    if (!result) NSBeep();
    
    return result;
}

// Presently, WEKWebEditorView doesn't implement paste directly itself, so we can jump in here
- (IBAction)paste:(id)sender;
{
    if (![[self delegate] webEditor:self doCommandBySelector:_cmd])
    {
        // Does the text view want to take command?
        if (![_focusedText webEditorTextDoCommandBySelector:_cmd])
        {
            [self forceWebViewToPerform:_cmd withObject:sender];
        }
    }
}

- (void)delete:(id)sender forwardingSelector:(SEL)action;
{
    if ([self selectedDOMRange])
    {
        [self forceWebViewToPerform:action withObject:sender];
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

#pragma mark Links

- (void)createLink:(SVLinkInspector *)sender;
{
    //  Pass on to focused text
    if (![[self dataSource] webEditor:self createLink:sender])
    {
        if ([[self focusedText] respondsToSelector:_cmd])
        {
            [[self focusedText] performSelector:_cmd withObject:sender];
        }
    }
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

#pragma mark Validation

- (BOOL)validateAction:(SEL)action;
{
    BOOL result = NO;
    
    NSView *view = [[[[self webView] selectedFrame] frameView] documentView];
    if ([view respondsToSelector:action])
    {
        result = YES;
        if ([view conformsToProtocol:@protocol(NSUserInterfaceValidations)] ||
            [view respondsToSelector:@selector(validateUserInterfaceItem:)])
        {
            SVValidatedUserInterfaceItem *item = [[SVValidatedUserInterfaceItem alloc] init];
            [item setAction:action];
            
            _isForwardingCommandToWebView = YES;
            result = [(id)view validateUserInterfaceItem:item];
            _isForwardingCommandToWebView = NO;
            
            [item release];
        }
    }
    
    
    return result;
}

@end


#pragma mark -


@implementation SVValidatedUserInterfaceItem

@synthesize action = _action;
@synthesize tag = _tag;

@end

