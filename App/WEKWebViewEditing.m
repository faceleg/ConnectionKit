//
//  WEKWebViewEditing.m
//  Sandvox
//
//  Created by Mike on 27/05/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "WEKWebViewEditing.h"

#import "DOMRange+Karelia.h"


#pragma mark -


@interface DOMDocument (SemiPublicEditingAPI)
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

- (void)createLink:(NSString *)link userInterface:(BOOL)userInterface;
{
    DOMRange *selection = [self selectedDOMRange];
    if ([selection collapsed])
    {
        [self selectWord:self];
        selection = [self selectedDOMRange];
    }
    
    DOMDocument *document = [[self mainFrame] DOMDocument];
    if ([document execCommand:@"createLink" userInterface:userInterface value:link])
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:WebViewDidChangeNotification object:self];
    }
    else
    {
        NSBeep();
    }
}

- (void)unlink:(id)sender;
{
    DOMRange *selection = [self selectedDOMRange];
    if ([selection collapsed])
    {
        DOMHTMLAnchorElement *anchor = [selection editableAnchorElement];
        [selection selectNode:anchor];
        [self setSelectedDOMRange:selection affinity:NSSelectionAffinityDownstream];
    }
    
    DOMDocument *document = [[self mainFrame] DOMDocument];
    if (![document execCommand:@"unlink" userInterface:NO value:nil]) NSBeep();
}

@end
