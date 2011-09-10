//
//  WEKWebViewEditing.m
//  Sandvox
//
//  Created by Mike on 27/05/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "WEKWebViewEditing.h"

#import "SVWebViewSelectionController.h"

#import "DOMRange+Karelia.h"
#import "NSString+Karelia.h"


#pragma mark -


@implementation WebView (WEKWebViewEditing)

#pragma mark Alignment

- (NSTextAlignment)wek_alignment;
{
    NSTextAlignment result = NSNaturalTextAlignment;
    
    DOMDocument *doc = [[self selectedFrame] DOMDocument];
    if ([[doc queryCommandValue:@"justifyleft"] isEqualToStringCaseInsensitive:@"true"])
    {
        result = NSLeftTextAlignment;
    }
    else if ([[doc queryCommandValue:@"justifycenter"] isEqualToStringCaseInsensitive:@"true"])
    {
        result = NSCenterTextAlignment;
    }
    else if ([[doc queryCommandValue:@"justifyright"] isEqualToStringCaseInsensitive:@"true"])
    {
        result = NSRightTextAlignment;
    }
    else if ([[doc queryCommandValue:@"justifyfull"] isEqualToStringCaseInsensitive:@"true"])
    {
        result = NSJustifiedTextAlignment;
    }
    
    return result;
}

#pragma mark Lists

- (IBAction)insertOrderedList:(id)sender;
{
    id delegate = [self editingDelegate];
    if ([delegate respondsToSelector:@selector(webView:doCommandBySelector:)])
    {
        if ([delegate webView:self doCommandBySelector:_cmd]) return;
    }
    
    if ([self orderedList]) return;  // nowt to do
    
    DOMDocument *document = [[self selectedFrame] DOMDocument];
    if ([document execCommand:@"InsertOrderedList"])
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:WebViewDidChangeNotification object:self];
    }
    else
    {
        NSBeep();
    }
}

- (IBAction)insertUnorderedList:(id)sender;
{
    id delegate = [self editingDelegate];
    if ([delegate respondsToSelector:@selector(webView:doCommandBySelector:)])
    {
        if ([delegate webView:self doCommandBySelector:_cmd]) return;
    }
    
    if ([self unorderedList]) return;  // nowt to do

    DOMDocument *document = [[self selectedFrame] DOMDocument];
    if (![document execCommand:@"InsertUnorderedList"])
    {
        NSBeep();
    }
}

- (IBAction)removeList:(id)sender;
{
    id delegate = [self editingDelegate];
    if ([delegate respondsToSelector:@selector(webView:doCommandBySelector:)])
    {
        if ([delegate webView:self doCommandBySelector:_cmd]) return;
    }
    
    
    DOMRange *selection = [self selectedDOMRange];
    if (!selection)
    {
        NSBeep();
        return;
    }
    
    SVWebViewSelectionController *controller = [[SVWebViewSelectionController alloc] init];
    [controller setSelectedDOMRange:selection];
    
    while ([[controller deepestListIndentLevel] unsignedIntegerValue])
    {
        [[[self selectedFrame] DOMDocument] execCommand:@"Outdent"];
        
        selection = [self selectedDOMRange];
        if (!selection) break;
        [controller setSelectedDOMRange:[self selectedDOMRange]];
    }
    
    [controller release];
}

- (BOOL)orderedList;
{
    DOMDocument *document = [[self selectedFrame] DOMDocument];
    return [document queryCommandState:@"InsertOrderedList"];
}

- (BOOL)unorderedList;
{
    DOMDocument *document = [[self selectedFrame] DOMDocument];
    return [document queryCommandState:@"InsertUnorderedList"];
}

@end


#pragma mark -


