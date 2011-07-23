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
#import "NSString+Karelia.h"


#pragma mark -


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
        DOMElement *anchor = [link createDOMElementInDocument:document];
        
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
    DOMRange *selection = [self selectedDOMRange];
    if ([selection collapsed])
    {
        [self selectLink:self];
        selection = [self selectedDOMRange];
    }
    
    if (!selection) return NSBeep();
    
    
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

#pragma mark Selection

- (WEKSelection *)wek_selection;
{
    DOMRange *selection = [self selectedDOMRange];
    if (selection)
    {
        return [[[WEKSelection alloc] initWithDOMRange:selection
                                              affinity:[self selectionAffinity]] autorelease];
    }
    return nil;
}

- (void)wek_setSelection:(WEKSelection *)selection;
{
    if (selection)
    {
        DOMRange *range = [self selectedDOMRange];
        if (!range) range = [[[selection startContainer] ownerDocument] createRange];
        
        [range setStart:[selection startContainer] offset:[selection startOffset]];
        [range setEnd:[selection endContainer] offset:[selection endOffset]];
        
        [self setSelectedDOMRange:range affinity:[selection affinity]];
    }
    else
    {
        [self setSelectedDOMRange:nil affinity:0];
    }
}

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
    if ([document execCommand:@"InsertUnorderedList"])
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:WebViewDidChangeNotification object:self];
    }
    else
    {
        NSBeep();
    }
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


@implementation WEKSelection

- (id)initWithDOMRange:(DOMRange *)range affinity:(NSSelectionAffinity)affinity;
{
    [self init];
    
    _startContainer = [[range startContainer] retain];
    _startOffset = [range startOffset];
    _endContainer = [[range endContainer] retain];
    _endOffset = [range endOffset];
    _affinity = affinity;
    
    return self;
}

- (void)dealloc
{
    [_startContainer release];
    [_endContainer release];
    
    [super dealloc];
}

@synthesize startContainer = _startContainer;
@synthesize startOffset = _startOffset;
@synthesize endContainer = _endContainer;
@synthesize endOffset = _endOffset;
@synthesize affinity = _affinity;

@end

