//
//  SVWebViewController.m
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebViewController.h"

#import "SVHTMLTemplateParser.h"
#import "SVHTMLTemplateTextBlock.h"
#import "KTPage.h"
#import "SVPagelet.h"
#import "SVPageletBody.h"
#import "SVPageletBodyTextAreaController.h"
#import "KTSite.h"
#import "SVWebContentItem.h"
#import "SVSelectionBorder.h"
#import "SVWebTextArea.h"

#import "DOMNode+Karelia.h"
#import "NSArray+Karelia.h"
#import "NSURL+Karelia.h"
#import "NSWorkspace+Karelia.h"

#import "KSSilencingConfirmSheet.h"


@interface SVWebViewController ()
- (void)loadPage:(KTPage *)page;
@property(nonatomic, readwrite, getter=isLoading) BOOL loading;

@property(nonatomic, copy, readwrite) NSArray *textAreas;
@property(nonatomic, copy, readwrite) NSArray *textAreaControllers;

@property(nonatomic, copy, readwrite) NSArray *contentItems;

@end


#pragma mark -


@implementation SVWebViewController

#pragma mark Init & Dealloc

- (void)dealloc
{
    [self setWebEditorView:nil];   // needed to tear down data source
    
    [_page release];
    OBASSERT(!_parsedTextBlocks); [_parsedTextBlocks release];
    [_textAreas release];
    
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
	SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc] initWithPage:page];
	
	/*KTWebViewComponent *webViewComponent = [[KTWebViewComponent alloc] initWithParser:parser];
	[self setMainWebViewComponent:webViewComponent];*/
	[parser setDelegate:self];
	//[webViewComponent release];*/
	
	[parser setHTMLGenerationPurpose:kGeneratingPreview];
	//[parser setIncludeStyling:([self viewType] != KTWithoutStylesView)];
	
    OBASSERT(!_parsedTextBlocks);
    _parsedTextBlocks = [[NSMutableArray alloc] init];
    
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

- (void)HTMLParser:(SVHTMLTemplateParser *)parser didParseTextBlock:(SVHTMLTemplateTextBlock *)textBlock;
{
    if ([textBlock isEditable]) [_parsedTextBlocks addObject:textBlock];
}

@synthesize loading = _isLoading;

- (void)webEditorViewDidFinishLoading:(SVWebEditorView *)sender;
{
    DOMDocument *domDoc = [[self webEditorView] DOMDocument];
    
    
    // Set up selection borders for all pagelets. Could we do this better by receiving a list of pagelets from the parser?
    NSSet *pagelets = [[[self page] sidebar] pagelets];
    NSMutableArray *contentObjects = [[NSMutableArray alloc] initWithCapacity:[pagelets count]];
    
    for (SVPagelet *aPagelet in pagelets)
    {
        DOMElement *element = [domDoc getElementById:[aPagelet elementID]];
        if (element)
        {
            SVWebContentItem *item = [[SVWebContentItem alloc] initWithDOMElement:element];
            [item setRepresentedObject:aPagelet];
            
            [contentObjects addObject:item];
            [item release];
        }
        else
        {
            NSLog(@"Could not locate pagelet with ID: %@", [aPagelet elementID]);
        }
    }
    
    [self setContentItems:contentObjects];
    [contentObjects release];
    
    
    
    // Prepare text areas and their controllers
    NSMutableArray *textAreas = [[NSMutableArray alloc] initWithCapacity:[_parsedTextBlocks count]];
    NSMutableArray *textAreaControllers = [[NSMutableArray alloc] init];
    
    for (SVHTMLTemplateTextBlock *aTextBlock in _parsedTextBlocks)
    {
        // Basic text area
        DOMHTMLElement *element = (DOMHTMLElement *)[domDoc getElementById:[aTextBlock DOMNodeID]];
        OBASSERT([element isKindOfClass:[DOMHTMLElement class]]);
        
        SVWebTextArea *textArea = [[SVWebTextArea alloc] initWithDOMElement:element];
        [textArea setRichText:[aTextBlock isRichText]];
        [textArea setFieldEditor:[aTextBlock isFieldEditor]];
        
        [textAreas addObject:textArea];
        [textArea release];
        
        
        // Binding
        id value = [[aTextBlock HTMLSourceObject] valueForKeyPath:[aTextBlock HTMLSourceKeyPath]];
        if ([value isKindOfClass:[SVPageletBody class]])
        {
            SVPageletBodyTextAreaController *controller = [[SVPageletBodyTextAreaController alloc]
                                                           initWithTextArea:textArea content:value];
            [textAreaControllers addObject:controller];
            [controller release];
        }
        else
        {
            [textArea bind:NSValueBinding
                     toObject:[aTextBlock HTMLSourceObject]
                  withKeyPath:[aTextBlock HTMLSourceKeyPath]
                      options:nil];
        }
    }
    
    [self setTextAreas:textAreas];
    [textAreas release];
    [self setTextAreaControllers:textAreaControllers];
    [textAreaControllers release];
    [_parsedTextBlocks release], _parsedTextBlocks = nil;
    
    
    
    
    
    
    // Locate the sidebar
    _sidebarDiv = [[domDoc getElementById:@"sidebar"] retain];
    
    
    // Mark as loaded
    [self setLoading:NO];
    
}

#pragma mark Text Areas

@synthesize textAreas = _textAreas;

- (SVWebTextArea *)textAreaForDOMNode:(DOMNode *)node;
{
    SVWebTextArea *result = nil;
    DOMHTMLElement *editableElement = [node containingContentEditableElement];
    
    if (editableElement)
    {
        // Search each text block in turn for a match
        for (result in [self textAreas])
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
            if (parent) result = [self textAreaForDOMNode:parent];
        }
    }
    
    return result;
}

- (SVWebTextArea *)textAreaForDOMRange:(DOMRange *)range;
{
    // One day there might be better logic to apply, but for now, testing the start of the range is enough
    return [self textAreaForDOMNode:[range startContainer]];
}

@synthesize textAreaControllers = _textAreaControllers;

#pragma mark Content Items

@synthesize contentItems = _contentItems;

#pragma mark Delegate

@synthesize delegate = _delegate;

#pragma mark WebEditorViewDataSource

- (NSArray *)webEditorView:(SVWebEditorView *)sender childrenOfItem:(id <SVWebEditorItem>)item;
{
    NSArray *result = [self contentItems];
    for (SVPageletBodyTextAreaController *aController in [self textAreaControllers])
    {
        result = [result arrayByAddingObjectsFromArray:[aController editorItems]];
    }
    
    return result;
}

- (id <SVWebEditorText>)webEditorView:(SVWebEditorView *)sender
                 textBlockForDOMRange:(DOMRange *)range;
{
    return [self textAreaForDOMRange:range];
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
    
    NSArray *pboardReps = [items valueForKeyPath:@"representedObject.elementID"];
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
    
    NSInteger i, count = [pagelets count] - 1;  // must use signed integer for now to handle 0 pagelets
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

