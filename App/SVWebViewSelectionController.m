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

- (void)createLink:(SVLink *)link userInterface:(BOOL)userInterface;
{
    [self createLinkWithValue:[link URLString]];
    if ([link openInNewWindow])
    {
        [self makeSelectedLinksOpenInNewWindow];
        [[NSNotificationCenter defaultCenter] postNotificationName:WebViewDidChangeNotification object:[self webView]];
    }
}

- (BOOL)createLinkWithValue:(NSString *)href;
{
    if ([super createLinkWithValue:href]) return YES;
    
    // Create our own link so it has correct text content. #104879
    SVLink *link = [SVLink linkWithURLString:href openInNewWindow:NO];
    DOMDocument *document = [self selectedDOMDocument];
    DOMElement *anchor = [link createDOMElementInDocument:document];
    
    // Ask for permission
    WebView *webView = [self webView];
    DOMRange *selection = [self selection];
    
    if ([[webView editingDelegate] webView:webView shouldInsertNode:anchor replacingDOMRange:selection givenAction:WebViewInsertActionTyped])
    {
        [selection insertNode:anchor];
        
        [selection selectNode:anchor];
        [webView setSelectedDOMRange:selection affinity:NSSelectionAffinityDownstream];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:WebViewDidChangeNotification object:self];
    }
    
    return YES;
}

- (void)makeSelectedLinksOpenInNewWindow
{
    NSArray *anchors = [self selectedAnchorElements];
    for (DOMHTMLAnchorElement *anAnchor in anchors)
    {
        [anAnchor setTarget:@"_blank"];
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
