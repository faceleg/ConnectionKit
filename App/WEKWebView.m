//
//  WEKWebView.m
//  Sandvox
//
//  Created by Mike on 23/09/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "WEKWebView.h"
#import "WebEditingKit.h"

#import "SVLinkManager.h"

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
    // Let delegate have a crack at it. (WebView doesn't inform delegate by default)
    if (![[[self webEditor] delegate] webEditor:[self webEditor]
                            doCommandBySelector:_cmd])
    {
        [super reload:sender];
    }
}

- (void)createLink:(SVLinkManager *)sender;
{
    // Ask for permisson, both for the action, and then the edit
    
    NSObject *delegate = [self editingDelegate];
    if ([delegate respondsToSelector:@selector(webView:shouldPerformAction:fromSender:)])
    {
        if (![delegate webView:self shouldPerformAction:_cmd fromSender:sender]) return;
    }
    
    DOMRange *selection = [self selectedDOMRange];
    if (selection)
    {
        if ([[self webEditor] shouldChangeTextInDOMRange:selection])
        {
            SVLink *link = [sender selectedLink];
            [self createLink:link userInterface:NO];
        }
    }
}

- (void)makeSelectedLinksOpenInNewWindow
{
    // Need to ask permission before doing so. If not, after the change, web editor may well not know what changed
    DOMRange *selection = [self selectedDOMRange];
    if (selection && [[self webEditor] shouldChangeTextInDOMRange:selection])
    {
        [super makeSelectedLinksOpenInNewWindow];
    }
}

#pragma mark Formatting

- (IBAction)clearStyles:(id)sender
{
    // Check delegate does not wish to intercept instead
    if ([[self editingDelegate] webView:self doCommandBySelector:_cmd]) return;
    
    
    DOMDocument *document = [[self selectedFrame] DOMDocument];
    if ([document execCommand:@"removeFormat" userInterface:NO value:nil])
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:WebViewDidChangeNotification
                                                            object:self];
    }
    else
    {
        NSBeep();
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem;
{
    if ([menuItem action] == @selector(clearStyles:))
    {
        DOMDocument *document = [[self selectedFrame] DOMDocument];
        BOOL result = [document queryCommandEnabled:@"removeFormat"];
        return result;
    }
    else
    {
        return [super validateMenuItem:menuItem];
    }
}

#pragma mark Dragging Destination

- (NSDragOperation)willUpdateDrag:(id <NSDraggingInfo>)sender result:(NSDragOperation)result;
{
    // Once we know the drag is supported, draw it. Can't do this from delegate methods as they are called even when an editing drag won't be allowed.
    if (!_delegateWillHandleDraggingInfo && result)
    {
        if (result == NSDragOperationCopy &&
            [sender draggingSource] == [self webEditor] &&
            [sender draggingSourceOperationMask] & NSDragOperationGeneric)
        {
            result = NSDragOperationGeneric;
        }
        
        NSPoint point = [self convertPointFromBase:[sender draggingLocation]];
        DOMRange *editingRange = [self editableDOMRangeForPoint:point];
        [[self webEditor] moveDragHighlightToDOMNode:[editingRange commonAncestorContainer]];
    }
    
    return result;
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
            NSLog(@"Delegate expected to handle drop, but WebView still did anyway");
            _delegateWillHandleDraggingInfo = NO;
            result = superOp;
        }
    }
    else
    {
        _delegateWillHandleDraggingInfo = NO;
        result = [super draggingEntered:sender];
    }
    
    
    result = [self willUpdateDrag:sender result:result];
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
            [self draggingExited:sender];
            _delegateWillHandleDraggingInfo = YES;
        }
    }
    else
    {
        _delegateWillHandleDraggingInfo = NO;
        
        WEKWebEditorView *webEditor = [self webEditor];
        [webEditor performSelector:@selector(removeDragCaretFromDOMNodes)];
        [webEditor moveDragHighlightToDOMNode:nil];
    
        result = [super draggingUpdated:sender];
    }
    
    
    result = [self willUpdateDrag:sender result:result];
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

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;
{
    if (_delegateWillHandleDraggingInfo)
    {
        NSObject *delegate = [[self webEditor] draggingDestinationDelegate];
        if ([delegate respondsToSelector:_cmd])
        {
            [delegate concludeDragOperation:sender];
        }
    }
    else
    {
        [super concludeDragOperation:sender];
    }
}

@end

