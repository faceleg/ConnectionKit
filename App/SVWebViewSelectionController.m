//
//  SVWebViewSelectionController.m
//  Sandvox
//
//  Created by Mike on 21/08/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVWebViewSelectionController.h"

#import "SVLinkManager.h"

#import "DOMRange+Karelia.h"


@implementation SVWebViewSelectionController

#pragma mark Links

- (DOMDocument *)selectedDOMDocument;
{
    return [[[self selection] commonAncestorContainer] ownerDocument];
}

- (BOOL)canCreateLink;
{
    BOOL result = [[self selectedDOMDocument] queryCommandEnabled:@"createLink"];
    return result;
}

- (BOOL)canUnlink;
{
    BOOL result = [[self selectedDOMDocument] queryCommandEnabled:@"unlink"];
    return result;
}

- (SVLink *)selectedLink;
{
    SVLink *result = nil;
    
    NSArray *anchors = [self selectedAnchorElements];
    if ([anchors count] == 1)
    {
        DOMHTMLAnchorElement *anchor = [anchors objectAtIndex:0];
        
        result = [SVLink linkWithURLString:[anchor getAttribute:@"href"]    // -href sometimes returns full URLs. #111645
                           openInNewWindow:[[anchor target] isEqualToString:@"_blank"]];
    }
    else if ([anchors count] > 1)
    {
        NSSet *anchorsSet = [[NSSet alloc] initWithArray:anchors];
        NSSet *targets = [anchorsSet valueForKey:@"target"];
        [anchorsSet release];
        
        if ([targets count] == 1)
        {
            NSString *href = [[anchors objectAtIndex:0] getAttribute:@"href"]; // see above
            for (DOMHTMLAnchorElement *anAnchor in anchors)
            {
                if (![[anAnchor getAttribute:@"href"] isEqualToString:href]) break;
            }
            
            result = [SVLink linkWithURLString:href
                               openInNewWindow:[[targets anyObject] isEqualToString:@"_blank"]];
        }
    }
    
    return result;
}

- (NSArray *)selectedAnchorElements;
{
    return [[self selection] ks_intersectingElementsWithTagName:@"A"];
}

- (NSString *)linkValue;
{
    NSString *result = [[self selectedDOMDocument] queryCommandValue:@"createLink"];
    return result;
}

- (void)createLink:(SVLink *)link userInterface:(BOOL)userInterface;
{
    DOMRange *selection = [self selection];
    if ([selection collapsed])
    {
        // Try to modify existing link
        [self selectLink:self];
        selection = [self selection];
        
        if ([selection collapsed])
        {
            // Fall back to turning the nearest word into a link
            [self selectWord:self];
            selection = [self selection];
        }
    }
    
    
    DOMDocument *document = [self selectedDOMDocument];
    if ([selection collapsed])
    {
        // Create our own link so it has correct text content. #104879
        DOMElement *anchor = [link createDOMElementInDocument:document];
        
        // Ask for permission
        WebView *webView = [[document webFrame] webView];
        
        if ([[webView editingDelegate] webView:webView shouldInsertNode:anchor replacingDOMRange:selection givenAction:WebViewInsertActionTyped])
        {
            [selection insertNode:anchor];
            
            [selection selectNode:anchor];
            [webView setSelectedDOMRange:selection affinity:NSSelectionAffinityDownstream];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:WebViewDidChangeNotification object:self];
        }
    }
    else
    {
        // Let the system take care of turning the current selection into a link
        if ([document execCommand:@"createLink" userInterface:userInterface value:[link URLString]])
        {
            if ([link openInNewWindow])
            {
                [self makeSelectedLinksOpenInNewWindow];
                
            }
            
            [[NSNotificationCenter defaultCenter] postNotificationName:WebViewDidChangeNotification object:self];
        }
        else
        {
            NSBeep();
        }
    }
}

- (void)makeSelectedLinksOpenInNewWindow
{
    NSArray *anchors = [self selectedAnchorElements];
    for (DOMHTMLAnchorElement *anAnchor in anchors)
    {
        [anAnchor setTarget:@"_blank"];
    }
    
}

- (void)unlink:(id)sender;
{
    DOMRange *selection = [self selection];
    if ([selection collapsed])
    {
        [self selectLink:self];
        selection = [self selection];
    }
    
    if (!selection) return NSBeep();
    
    
    // Ask for permission. Not sure what the best delegate method to use is :(
    WebView *webView = [[[self selectedDOMDocument] webFrame] webView];
    
    if ([[webView editingDelegate] respondsToSelector:@selector(webView:shouldDeleteDOMRange:)])
    {
        if (![[webView editingDelegate] webView:webView shouldDeleteDOMRange:selection])
        {
            NSBeep();
            return;
        }
    }
    
    
    if ([[self selectedDOMDocument] execCommand:@"unlink" userInterface:NO value:nil])
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
    DOMRange *selection = [self selection];
    DOMHTMLAnchorElement *anchor = [selection editableAnchorElement];
    if (anchor)
    {
        [selection selectNode:anchor];
        [[[[self selectedDOMDocument] webFrame] webView] setSelectedDOMRange:selection affinity:NSSelectionAffinityDownstream];
    }
}

- (void)createLink:(SVLinkManager *)sender;
{
    // Ask for permisson, both for the action, and then the edit
    WebView *webView = [[[self selectedDOMDocument] webFrame] webView];
    
    NSObject *delegate = [webView editingDelegate];
    if ([delegate respondsToSelector:@selector(webView:shouldPerformAction:fromSender:)])
    {
        if (![delegate webView:webView shouldPerformAction:_cmd fromSender:sender]) return;
    }
    
    DOMRange *selection = [self selection];
    if (selection)
    {
        SVLink *link = [sender selectedLink];
        [self createLink:link userInterface:NO];
    }
}

@end
