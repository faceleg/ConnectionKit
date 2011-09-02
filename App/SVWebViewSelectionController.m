//
//  SVWebViewSelectionController.m
//  Sandvox
//
//  Created by Mike on 21/08/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVWebViewSelectionController.h"

#import "SVLinkManager.h"

#import "DOMNode+Karelia.h"
#import "DOMRange+Karelia.h"


@implementation SVWebViewSelectionController

#pragma mark Lifecycle

- (id)initWithWebView:(WebView *)webView;
{
    if (self = [self init])
    {
        _webView = [webView retain];
    }
    return self;
}

- (void)dealloc
{
    [_webView release];
    [_selection release];
    
    [super dealloc];
}

#pragma mark WebView

@synthesize selection = _selection;
- (void)setSelection:(DOMRange *)selection;
{
    // Wind the end of the selection in, as WebKit can be a little enthusiastic, selecting up to the start of following paragraph
    if (selection)
    {
        // Wind in to end of text
        while (![selection collapsed] &&
               ([selection endOffset] == 0 || [[selection endContainer] nodeType] != DOM_TEXT_NODE))
        {
            [selection ks_collapseBy1];
        }
    }
    
    [selection retain];
    [_selection release]; _selection = selection;
}
+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key;
{
    if ([key isEqualToString:@"listIndentLevel"] ||
        [key isEqualToString:@"shallowestListIndentLevel"] ||
        [key isEqualToString:@"listTypeTag"])
    {
        return [NSSet setWithObject:@"selection"];
    }
    else
    {
        return [super keyPathsForValuesAffectingValueForKey:key];
    }
}

#pragma mark Strikethrough

- (void)strikethrough:(id)sender;
{
    DOMRange *selection = [self selection];
    DOMDocument *doc = [[selection commonAncestorContainer] ownerDocument];
    if (![doc execCommand:@"Strikethrough"])
    {
        [[self nextResponder] doCommandBySelector:_cmd];
    }
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem;
{
    if ([anItem action] == @selector(strikethrough:))
    {
        DOMRange *selection = [self selection];
        DOMDocument *doc = [[selection commonAncestorContainer] ownerDocument];
        return [doc queryCommandEnabled:@"Strikethrough"];
    }
    else
    {
        return YES;
    }
}

#pragma mark Lists

+ (NSSet *)listTagNames;
{
    static NSSet *listTags;
    if (!listTags) listTags = [[NSSet alloc] initWithObjects:@"UL", @"OL", nil];
    return listTags;
}

#pragma mark Indentation

- (NSNumber *)listIndentLevel;
{
    if (!_selection) return NSNoSelectionMarker;
    
    
    // How many levels deep is the selection?
    NSNumber *result = [self shallowestListIndentLevel];
    
    
    // Does it contain sub-lists?
    id ancestor = [_selection commonAncestorContainer];
    while (![ancestor respondsToSelector:@selector(getElementsByTagName:)])
    {
        ancestor = [ancestor parentNode];
    }
    
    DOMNodeList *nodes = [ancestor getElementsByTagName:@"UL"];
    NSUInteger i, count = [nodes length];
    
    for (i = 0; i < count; i++)
    {
        DOMNode *aNode = [nodes item:i];
        if ([_selection intersectsNode:aNode]) return NSMultipleValuesMarker;
    }
    
    nodes = [ancestor getElementsByTagName:@"OL"];
    count = [nodes length];
    
    for (i = 0; i < count; i++)
    {
        DOMNode *aNode = [nodes item:i];
        if ([_selection intersectsNode:aNode]) return NSMultipleValuesMarker;
    }
    
    
    return result;
}

- (void)setListIndentLevel:(NSNumber *)aLevel;
{
    NSUInteger level = [aLevel unsignedIntegerValue];
    if (level < 1 || level > 9) return;
    
    NSNumber *currentLevel = [self shallowestListIndentLevel];
    if (![currentLevel isKindOfClass:[NSNumber class]]) return;
    
    if ([currentLevel unsignedIntegerValue] > level)
    {
        do
        {
            [[[[self selection] commonAncestorContainer] documentView]
             doCommandBySelector:@selector(outdent:)];
        }
        while ([[self shallowestListIndentLevel] unsignedIntegerValue] > level);
    }
    else if ([currentLevel unsignedIntegerValue] < level)
    {
        while ([[self deepestListIndentLevel] unsignedIntegerValue] < 9)
        {
            [[[[self selection] commonAncestorContainer] documentView]
             doCommandBySelector:@selector(indent:)];
            
            if ([[self shallowestListIndentLevel] unsignedIntegerValue] >= level) break;
        }
    }
}

- (NSNumber *)shallowestListIndentLevel;
{
    if (!_selection) return NSNoSelectionMarker;
    
    // Whole thing must be contained within a list to have more than 0 level
    NSUInteger result = [self listIndentLevelForDOMNode:[_selection commonAncestorContainer]];
    if (result)
    {
        NSArray *listItems = [_selection ks_intersectingElementsWithTagName:@"LI"];
        if ([listItems count])
        {
            result = NSUIntegerMax;
            
            for (DOMElement *anItem in listItems) 
            {
                NSUInteger level = [self listIndentLevelForDOMNode:anItem];
                if (level < result) result = level;
                if (level <= 1) break;  // get out early clause!
            }
        }
    }
    
    return [NSNumber numberWithUnsignedInteger:result];
}

- (NSNumber *)deepestListIndentLevel;
{
    if (!_selection) return NSNoSelectionMarker;
    
    
    NSUInteger result = 0;
    
    // Get all the contained list elements
    id ancestor = [_selection commonAncestorContainer];
    while (![ancestor respondsToSelector:@selector(getElementsByTagName:)])
    {
        ancestor = [ancestor parentNode];
    }
    
    DOMNodeList *nodes = [ancestor getElementsByTagName:@"LI"];
    NSUInteger i, count = [nodes length];
    
    for (i = 0; i < count; i++)
    {
        DOMNode *aNode = [nodes item:i];
        if ([_selection intersectsNode:aNode])
        {
            NSUInteger level = [self listIndentLevelForDOMNode:aNode];
            if (level > result) result = level;
        }
    }
    
    
    return (result ? [NSNumber numberWithUnsignedInteger:result] : [self shallowestListIndentLevel]);
}

- (NSUInteger)listIndentLevelForDOMNode:(DOMNode *)node;
{
    
    NSUInteger result = 0;
    DOMElement *list = [node ks_ancestorWithTagNameInSet:[[self class] listTagNames]];
    while (list)
    {
        result++;
        list = [[list parentNode] ks_ancestorWithTagNameInSet:[[self class] listTagNames]];
    }
    
    return result;
}

#pragma mark Type

- (NSNumber *)listTypeTag
{
    if (!_selection) return NSNoSelectionMarker;
    
    
    // Inside a list?
    NSNumber *level = [self shallowestListIndentLevel];
    BOOL listOnly = ([level isKindOfClass:[NSNumber class]] && [level unsignedIntegerValue] > 0);
    
    // What list items are selected?
    NSArray *listItems = [_selection ks_intersectingElementsWithTagName:@"LI"];
    if (![listItems count]) return [NSNumber numberWithInt:0];
    if (!listOnly) return NSMultipleValuesMarker;
    
    // Multiple selection?
    NSUInteger result = [self listTypeTagForDOMNode:[listItems objectAtIndex:0]];
    
    NSUInteger i, count = [listItems count];
    for (i = 1; i < count; i++)
    {
        DOMElement *anElement = [listItems objectAtIndex:i];
        if ([self listTypeTagForDOMNode:anElement] != result) return NSMultipleValuesMarker;
    }
    
    return [NSNumber numberWithUnsignedInteger:result];
}

- (NSNumber *)isOrderedList;
{
    NSNumber *result = [self listTypeTag];
    if ([result isKindOfClass:[NSNumber class]])
    {
        result = NSBOOL([result unsignedIntegerValue] == 2);
    }
    return result;
}
+ (NSSet *)keyPathsForValuesAffectingIsOrderedList;
{
    return [NSSet setWithObject:@"listTypeTag"];
}


- (NSUInteger)listTypeTagForDOMNode:(DOMNode *)node;
{
    DOMElement *list = [node ks_ancestorWithTagNameInSet:[[self class] listTagNames]];
    if ([[list tagName] isEqualToString:@"UL"])
    {
        return 1;
    }
    else if ([[list tagName] isEqualToString:@"OL"])
    {
        return 2;
    }
    else
    {
        return 0;
    }
}

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

#pragma mark Responder Chain

- (void)insertIntoResponderChainAfterWebView:(WebView *)webView;
{
    [self setNextResponder:[webView nextResponder]];
    [webView setNextResponder:self];
}

@end
