//
//  SVWebViewController.m
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebViewController.h"

#import "KTHTMLParser.h"
#import "KTHTMLTextBlock.h"
#import "KTPage.h"
#import "KTSite.h"
#import "SVContainerTextBlock.h"
#import "SVWebContentItem.h"
#import "SVSelectionBorder.h"
#import "SVTextBlock.h"

#import "DOMNode+Karelia.h"
#import "NSArray+Karelia.h"
#import "NSURL+Karelia.h"
#import "NSWorkspace+Karelia.h"

#import "KSSilencingConfirmSheet.h"


@interface SVWebViewController ()
- (void)loadPage:(KTPage *)page;
@property(nonatomic, readwrite, getter=isLoading) BOOL loading;

@property(nonatomic, copy, readwrite) NSArray *textBlocks;
@property(nonatomic, retain, readwrite) SVTextBlock *selectedTextBlock;

@property(nonatomic, copy, readwrite) NSArray *contentItems;

@end


#pragma mark -


@implementation SVWebViewController

#pragma mark Init & Dealloc

- (void)dealloc
{
    [self setWebEditorView:nil];   // needed to tear down data source
    
    [_page release];
    OBASSERT(!_HTMLTextBlocks); [_HTMLTextBlocks release];
    [_textBlocks release];
    
    [super dealloc];
}

#pragma mark Views

- (void)loadView
{
    SVWebEditorView *editor = [[SVWebEditorView alloc] init];
    
    [self setView:editor];
    [self setWebEditorView:editor];
    [self setWebView:[editor webView]];
    
    // Register the editor for drag & drop
    [editor registerForDraggedTypes:[NSArray arrayWithObject:kKTPageletsPboardType]];
    
    [editor release];
}

- (void)setWebView:(WebView *)webView
{
    // Store new webview
    [super setWebView:webView];
    
    
    // Spell-checking
    // TODO: Define a constant or method for this
    BOOL spellCheck = [[NSUserDefaults standardUserDefaults] boolForKey:@"ContinuousSpellChecking"];
	[webView setContinuousSpellCheckingEnabled:spellCheck];
}

@synthesize webEditorView = _webEditorView;
- (void)setWebEditorView:(SVWebEditorView *)editor
{
    [[self webEditorView] setDelegate:nil];
    [[self webEditorView] setDataSource:nil];
    
    [editor retain];
    [_webEditorView release];
    _webEditorView = editor;
    
    [editor setDelegate:self];
    [editor setDataSource:self];
}

#pragma mark Loading

- (KTPage *)page { return _page; }

- (void)setPage:(KTPage *)page
{
    [page retain];
    [_page release];
    _page = page;
    
    if (page)
    {
        [self loadPage:page];
    }
    else
    {
        // TODO: load blank webview
    }
}

// Support
- (void)loadPage:(KTPage *)page;
{
    // Record that the webview is being loaded with content. Otherwise, the policy delegate will refuse requests.
    [self setLoading:YES];
    
    
	// Build the HTML
	KTHTMLParser *parser = [[KTHTMLParser alloc] initWithPage:page];
	
	/*KTWebViewComponent *webViewComponent = [[KTWebViewComponent alloc] initWithParser:parser];
	[self setMainWebViewComponent:webViewComponent];*/
	[parser setDelegate:self];
	//[webViewComponent release];*/
	
	[parser setHTMLGenerationPurpose:kGeneratingPreview];
	//[parser setIncludeStyling:([self viewType] != KTWithoutStylesView)];
	
    OBASSERT(!_HTMLTextBlocks);
    _HTMLTextBlocks = [[NSMutableArray alloc] init];
    
	NSString *pageHTML = [parser parseTemplate];
	[parser release];
	
    
    // Figure out the URL to use
	NSURL *pageURL = [page URL];
    if (![pageURL scheme] ||        // case 44071: WebKit will not load the HTML or offer delegate
        ![pageURL host] ||          // info if the scheme is something crazy like fttp:
        !([[pageURL scheme] isEqualToString:@"http"] || [[pageURL scheme] isEqualToString:@"https"]))
    {
        pageURL = nil;
    }
    
    
    // Load the HTML into the webview
    [[self webEditorView] loadHTMLString:pageHTML baseURL:pageURL];
}

- (void)HTMLParser:(KTHTMLParser *)parser didParseTextBlock:(KTHTMLTextBlock *)textBlock;
{
    if ([textBlock isEditable]) [_HTMLTextBlocks addObject:textBlock];
}

@synthesize loading = _isLoading;

- (void)webEditorViewDidFinishLoading:(WebView *)sender;
{
    // Prepare controllers for each text block
    NSMutableArray *controllers = [[NSMutableArray alloc] initWithCapacity:[_HTMLTextBlocks count]];
    DOMDocument *domDoc = [[self webEditorView] DOMDocument];
    
    for (KTHTMLTextBlock *aTextBlock in _HTMLTextBlocks)
    {
        // Basic controller
        DOMHTMLElement *element = (DOMHTMLElement *)[domDoc getElementById:[aTextBlock DOMNodeID]];
        OBASSERT([element isKindOfClass:[DOMHTMLElement class]]);
        
        Class textBlockClass = ([aTextBlock importsGraphics] ? [SVContainerTextBlock class] : [SVBindableTextBlock class]);
        SVTextBlock *aController = [[textBlockClass alloc] initWithDOMElement:element];
        [aController setRichText:[aTextBlock isRichText]];
        [aController setFieldEditor:[aTextBlock isFieldEditor]];
        
        [controllers addObject:aController];
        [aController release];
        
        // Binding
        [aController bind:NSValueBinding
                 toObject:[aTextBlock HTMLSourceObject]
              withKeyPath:[aTextBlock HTMLSourceKeyPath]
                  options:nil];
    }
    
    [self setTextBlocks:controllers];
    [_HTMLTextBlocks release], _HTMLTextBlocks = nil;
    
    
    
    
    
    
    // Set up selection borders for all pagelets. Could we do this better by receiving a list of pagelets from the parser?
    NSArray *pagelets = [[[self page] sidebarPagelets] arrayByAddingObjectsFromArray:[[self page] callouts]];
    NSMutableArray *contentObjects = [[NSMutableArray alloc] initWithCapacity:[pagelets count]];
    
    for (KTPagelet *aPagelet in pagelets)
    {
        NSString *pageletID = [@"k-" stringByAppendingString:aPagelet.uniqueID];
        DOMElement *element = [domDoc getElementById:pageletID];
        if (element)
        {
            SVWebContentItem *object = [[SVWebContentItem alloc] initWithDOMElement:element pagelet:aPagelet];
            [contentObjects addObject:object];
            [object release];
        }
        else
        {
            NSLog(@"Could not locate pagelet with ID: %@", pageletID);
        }
    }
    
    [self setContentItems:contentObjects];
    [contentObjects release];
    
    
    
    // Locate the sidebar
    _sidebarDiv = [[domDoc getElementById:@"sidebar"] retain];
    
    
    // Mark as loaded
    [self setLoading:NO];
    
}

#pragma mark Text Blocks

@synthesize textBlocks = _textBlocks;

- (SVTextBlock *)textBlockForDOMNode:(DOMNode *)node;
{
    SVTextBlock *result = nil;
    DOMHTMLElement *editableElement = [node containingContentEditableElement];
    
    if (editableElement)
    {
        // Search each text block in turn for a match
        for (result in [self textBlocks])
        {
            if ([result DOMElement] == editableElement)
            {
                break;
            }
        }
        
        // It's possible (but very unlikely) that the editable element is part of a text block's content. If so, search up for the next one
        if (!result)
        {
            DOMNode *parent = [editableElement parentNode];
            if (parent) result = [self textBlockForDOMNode:parent];
        }
    }
    
    return result;
}

- (SVTextBlock *)textBlockForDOMRange:(DOMRange *)range;
{
    // One day there might be better logic to apply, but for now, testing the start of the range is enough
    return [self textBlockForDOMNode:[range startContainer]];
}

@synthesize selectedTextBlock = _selectedTextBlock;

#pragma mark Content Items

@synthesize contentItems = _contentItems;

- (SVWebContentItem *)itemForNode:(DOMNode *)node inItems:(NSArray *)items
{
    SVWebContentItem *result = nil;
    for (result in items)
    {
        if ([node isDescendantOfNode:[result DOMElement]])
        {
            break;
        }
    }
    
    return result;
}

- (SVWebContentItem *)itemAtPoint:(NSPoint)point
{
    // This is the key to the whole operation. We have to decide whether events make it through to the WebView based on whether they would target a selectable object
    NSDictionary *elementInfo = [[self webView] elementAtPoint:point];
    DOMNode *node = [elementInfo objectForKey:WebElementDOMNodeKey];
    SVWebContentItem *result = nil;
    
    if (node)
    {
        result = [self itemForNode:node inItems:[self contentItems]];
        if (!result)
        {
            for (SVTextBlock *aTextBlock in [self textBlocks])
            {
                result = [self itemForNode:node inItems:[aTextBlock contentItems]];
                if (result) break;
            }
        }
    }
    
    return result;
}

#pragma mark Delegate

@synthesize delegate = _delegate;

#pragma mark WebEditorViewDataSource

- (id <SVWebEditorItem>)editingOverlay:(SVWebEditorView *)overlay itemAtPoint:(NSPoint)point;
{
    id <SVWebEditorItem> result = [self itemAtPoint:point];
    return result;
}

- (id <SVWebEditorText>)webEditorView:(SVWebEditorView *)sender
                 textBlockForDOMRange:(DOMRange *)range;
{
    return [self textBlockForDOMRange:range];
}

- (BOOL)webEditorView:(SVWebEditorView *)sender deleteItems:(NSArray *)items;
{
    return NO;
    // TODO: Implement deletion support
}

- (BOOL)webEditorView:(SVWebEditorView *)sender
           writeItems:(NSArray *)items
         toPasteboard:(NSPasteboard *)pasteboard;
{
    BOOL result = NO;
    
    NSArray *pboardReps = [items valueForKeyPath:@"pagelet.pasteboardRepresentation"];
    if (![pboardReps containsObjectIdenticalTo:[NSNull null]])
    {
        result = YES;
        
        [pasteboard declareTypes:[NSArray arrayWithObject:kKTPageletsPboardType]
                           owner:self];
        [pasteboard setData:[NSKeyedArchiver archivedDataWithRootObject:pboardReps]
                    forType:kKTPageletsPboardType];
    }
    
    
    return result;
}

- (NSDragOperation)webEditorView:(SVWebEditorView *)sender
      dataSourceShouldHandleDrop:(id <NSDraggingInfo>)dragInfo;
{
    NSDragOperation result = NSDragOperationNone;
    
    // Drags are generally fine unless they fall in the drop zone between pagelets.
    NSArray *pagelets = [self contentItems];
    
    NSUInteger i, count = [pagelets count] - 1;
    for (i = 0; i < count; i++)
    {
        SVWebEditorItem *item1 = [pagelets objectAtIndex:i];
        SVWebEditorItem *item2 = [pagelets objectAtIndex:i+1];
        
        
        NSRect aDropZone = [sender rectOfDragCaretAfterDOMNode:[item1 DOMElement]
                                                               beforeDOMNode:[item2 DOMElement]
                                                                 minimumSize:25.0f];;
        
        if ([sender mouse:[sender convertPointFromBase:[dragInfo draggingLocation]]
                 inRect:aDropZone])
        {
            result = NSDragOperationMove;
            [sender moveDragCaretToAfterDOMNode:[item1 DOMElement]
                                                beforeDOMNode:[item2 DOMElement]];
            break;
        }
    }
    
    
    return result;
}


#pragma mark SVWebEditorViewDelegate

- (void)webEditorView:(SVWebEditorView *)sender didReceiveTitle:(NSString *)title;
{
    [self setTitle:title];
}

- (void)webEditorView:(SVWebEditorView *)sender handleNavigationAction:(NSDictionary *)actionInfo request:(NSURLRequest *)request;
{
    NSURL *URL = [actionInfo objectForKey:@"WebActionOriginalURLKey"];
    
    
    // A link to another page within the document should open that page. Let the delegate take care of deciding how to open it
    NSURL *relativeURL = [URL URLRelativeToURL:[[self page] URL]];
    NSString *relativePath = [relativeURL relativePath];
    
    if (([[URL scheme] isEqualToString:@"applewebdata"] || [relativePath hasPrefix:kKTPageIDDesignator]) &&
        [[actionInfo objectForKey:WebActionNavigationTypeKey] intValue] != WebNavigationTypeOther)
    {
        KTPage *page = [[[self page] site] pageWithPreviewURLPath:relativePath];
        if (page)
        {
            [[self delegate] webEditorViewController:self openPage:page];
        }
        else if ([[self view] window])
        {
            [KSSilencingConfirmSheet alertWithWindow:[[self view] window]
                                        silencingKey:@"shutUpFakeURL"
                                               title:NSLocalizedString(@"Non-Page Link",@"title of alert")
                                              format:NSLocalizedString
             (@"You clicked on a link that would open a page that Sandvox cannot directly display.\n\n\t%@\n\nWhen you publish your website, you will be able to view the page with your browser.", @""),
             [URL path]];
        }
    }
    
    
    // Open normal links in the user's browser
    else if ([[URL scheme] isEqualToString:@"http"])
    {
        int navigationType = [[actionInfo objectForKey:WebActionNavigationTypeKey] intValue];
        switch (navigationType)
        {
            case WebNavigationTypeFormSubmitted:
            case WebNavigationTypeBackForward:
            case WebNavigationTypeReload:
            case WebNavigationTypeFormResubmitted:
                // 1.x allowed the webview to load these - do we want actually want to?
                break;
                
            case WebNavigationTypeOther:
                // Only allow the request if we're loading a page. BUGSID:26693 this stops meta tags refreshing the page
                break;
                
            default:
                // load with user's preferred browser:
                [[NSWorkspace sharedWorkspace] attemptToOpenWebURL:URL];
        }
    }
    
    // We used to do [listener use] for file: URLs. Why?
    // And again the fallback option for to -use. Why?
}

@end

