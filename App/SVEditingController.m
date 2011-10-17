//
//  SVEditingController.m
//  Sandvox
//
//  Created by Mike on 21/08/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVEditingController.h"

#import "SVLinkManager.h"
#import "SVSiteItem.h"

#import "NSResponder+Karelia.h"
#import "DOMRange+Karelia.h"


@implementation SVEditingController

- (DOMDocument *)selectedDOMDocument;
{
    return [[[self selectedDOMRange] commonAncestorContainer] ownerDocument];
}

#pragma mark Alignment

- (NSTextAlignment)wek_alignment;
{
    NSTextAlignment result = NSNaturalTextAlignment;
    
    DOMDocument *doc = [self selectedDOMDocument];
    if ([doc queryCommandState:@"justifyleft"])
    {
        result = NSLeftTextAlignment;
    }
    else if ([doc queryCommandState:@"justifycenter"])
    {
        result = NSCenterTextAlignment;
    }
    else if ([doc queryCommandState:@"justifyright"])
    {
        result = NSRightTextAlignment;
    }
    else if ([doc queryCommandState:@"justifyfull"])
    {
        result = NSJustifiedTextAlignment;
    }
    
    return result;
}

#pragma mark Links

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
        [self updateLinkManager];
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
    DOMRange *selection = [self selectedDOMRange];
    
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
    
    DOMRange *selection = [self selectedDOMRange];
    if (selection)
    {
        SVLink *link = [sender selectedLink];
        [self createLink:link userInterface:NO];
    }
}

- (void)updateLinkManager;
{
    NSWindow *window = [[self webView] window];
    if ([window isKeyWindow] || [window isMainWindow])  // will be main window if user tabs around link inspector. #119729
    {
        NSResponder *firstResponder = [window firstResponder];
        if ([self ks_followsResponder:firstResponder])
        {
            SVLink *link = [self selectedLink];
            if (link)
            {
                SVSiteItem *siteItem = [SVSiteItem 
                                        siteItemForPreviewPath:[link URLString]
                                        inManagedObjectContext:[[[window windowController] document] managedObjectContext]];   // HACK to get hold of MOC
                
                if (siteItem)
                {
                    link = [SVLink linkWithSiteItem:siteItem openInNewWindow:[link openInNewWindow]];
                }
            }
            
            [[SVLinkManager sharedLinkManager] setSelectedLink:link editable:[self canCreateLink]];;
        }
    }
}

- (void)webViewDidChangeSelection:(NSNotification *)notification
{
    [super webViewDidChangeSelection:notification];
    [self updateLinkManager];
}

#pragma mark Lists

- (IBAction)insertOrderedList:(id)sender;
{
    if ([self orderedList]) return;  // nowt to do
    [super insertOrderedList:sender];
}

- (IBAction)insertUnorderedList:(id)sender;
{
    if ([self unorderedList]) return;  // nowt to do
    [super insertUnorderedList:sender];
}

- (BOOL)orderedList;
{
    return [[self selectedDOMDocument] queryCommandState:@"InsertOrderedList"];
}

- (BOOL)unorderedList;
{
    return [[self selectedDOMDocument] queryCommandState:@"InsertUnorderedList"];
}

@end
