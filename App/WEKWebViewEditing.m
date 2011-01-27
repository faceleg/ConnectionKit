//
//  WEKWebViewEditing.m
//  Sandvox
//
//  Created by Mike on 27/05/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "WEKWebViewEditing.h"

#import "SVLink.h"

#import "DOMRange+Karelia.h"


#pragma mark -


@interface DOMDocument (AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER)
- (BOOL)execCommand:(NSString *)command userInterface:(BOOL)userInterface value:(NSString *)value;
- (BOOL)execCommand:(NSString *)command userInterface:(BOOL)userInterface;
- (BOOL)execCommand:(NSString *)command;
- (BOOL)queryCommandEnabled:(NSString *)command;
- (BOOL)queryCommandIndeterm:(NSString *)command;
- (BOOL)queryCommandState:(NSString *)command;
- (BOOL)queryCommandSupported:(NSString *)command;
- (NSString *)queryCommandValue:(NSString *)command;
@end


@implementation WebView (WEKWebViewEditing)

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

#pragma mark Links

- (BOOL)canCreateLink;
{
    DOMDocument *document = [[self selectedFrame] DOMDocument];
    BOOL result = [document queryCommandEnabled:@"createLink"];
    return result;
}

- (BOOL)canUnlink;
{
    DOMDocument *document = [[self selectedFrame] DOMDocument];
    BOOL result = [document queryCommandEnabled:@"unlink"];
    return result;
}

- (NSArray *)selectedAnchorElements;
{
    DOMRange *selection = [self selectedDOMRange];
    DOMHTMLAnchorElement *anchorElement = [selection editableAnchorElement];
    
    NSArray *result = nil;
    if (anchorElement) result = [NSArray arrayWithObject:anchorElement];
    return result;
}

- (NSString *)linkValue;
{
    DOMDocument *document = [[self selectedFrame] DOMDocument];
    NSString *result = [document queryCommandValue:@"createLink"];
    return result;
}

- (void)createLink:(SVLink *)link userInterface:(BOOL)userInterface;
{
    DOMRange *selection = [self selectedDOMRange];
    if ([selection collapsed])
    {
        // Try to modify existing link
        [self selectLink:self];
        selection = [self selectedDOMRange];
        
        if ([selection collapsed])
        {
            // Fall back to turning the nearest word into a link
            [self selectWord:self];
            selection = [self selectedDOMRange];
        }
    }
    
    
    DOMDocument *document = [[self mainFrame] DOMDocument];
    if ([selection collapsed])
    {
        // Create our own link so it has correct text content. #104879
        DOMHTMLAnchorElement *anchor = (DOMHTMLAnchorElement *)[document createElement:@"A"];
        [anchor setHref:[link URLString]];
        
        DOMText *text = [document createTextNode:[link targetDescription]];
        [anchor appendChild:text];
        
        // Ask for permission
        if ([[self editingDelegate] webView:self shouldInsertNode:anchor replacingDOMRange:selection givenAction:WebViewInsertActionTyped])
        {
            [selection insertNode:anchor];
            
            [selection selectNode:anchor];
            [self setSelectedDOMRange:selection affinity:NSSelectionAffinityDownstream];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:WebViewDidChangeNotification object:self];
        }
    }
    else
    {
        // Let the system take care of turning the current selection into a link
        if ([document execCommand:@"createLink" userInterface:userInterface value:[link URLString]])
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:WebViewDidChangeNotification object:self];
        }
        else
        {
            NSBeep();
        }
    }
}

- (void)unlink:(id)sender;
{
    DOMRange *selection = [self selectedDOMRange];
    if ([selection collapsed])
    {
        [self selectLink:self];
        selection = [self selectedDOMRange];
    }
    
    // Ask for permission. Not sure what the best delegate method to use is :(
    if ([[self editingDelegate] respondsToSelector:@selector(webView:shouldDeleteDOMRange:)])
    {
        if (![[self editingDelegate] webView:self shouldDeleteDOMRange:selection])
        {
            NSBeep();
            return;
        }
    }
    
    
    DOMDocument *document = [[self mainFrame] DOMDocument];
    if ([document execCommand:@"unlink" userInterface:NO value:nil])
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:WebViewDidChangeNotification object:self];
    }
    else
    {
        NSBeep();
    }
}

- (IBAction)selectLink:(id)sender;
{
    DOMRange *selection = [self selectedDOMRange];
    DOMHTMLAnchorElement *anchor = [selection editableAnchorElement];
    if (anchor)
    {
        [selection selectNode:anchor];
        [self setSelectedDOMRange:selection affinity:NSSelectionAffinityDownstream];
    }
}

@end
