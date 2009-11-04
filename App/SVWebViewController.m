//
//  SVWebViewController.m
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebViewController.h"

#import "SVContentObject.h"
#import "SVHTMLTemplateParser.h"
#import "SVHTMLTemplateTextBlock.h"
#import "KTPage.h"
#import "SVPagelet.h"
#import "SVPageletBody.h"
#import "SVPageletBodyTextAreaController.h"
#import "KTSite.h"
#import "SVWebContentItem.h"
#import "SVSelectionBorder.h"
#import "SVSidebar.h"
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


// Pagelets
@property(nonatomic, copy, readwrite) NSArray *contentItems;
- (NSRect)rectOfDropZoneAboveDOMNode:(DOMNode *)node minHeight:(CGFloat)minHeight;
- (NSRect)rectOfDropZoneInDOMElement:(DOMElement *)element
                           belowNode:(DOMNode *)node
                           minHeight:(CGFloat)minHeight;

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
	
    SVHTMLGenerationContext *context = [[SVHTMLGenerationContext alloc] init];
    [context setCurrentPage:page];
    [context setGenerationPurpose:kGeneratingPreview];
	//[parser setIncludeStyling:([self viewType] != KTWithoutStylesView)];
	
    OBASSERT(!_parsedTextBlocks);
    _parsedTextBlocks = [[NSMutableArray alloc] init];
    
	NSString *pageHTML = [parser parseTemplateWithContext:context];
    [context release];
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
    NSArray *pagelets = [SVPagelet arrayBySortingPagelets:[[[self page] sidebar] pagelets]];
    NSMutableArray *contentObjects = [[NSMutableArray alloc] initWithCapacity:[pagelets count]];
    
    for (SVPagelet *aPagelet in pagelets)
    {
        DOMElement *element = [domDoc getElementById:[aPagelet elementID]];
        if (element)
        {
            SVWebContentItem *item = [[SVWebContentItem alloc] initWithDOMElement:element];
            [item setRepresentedObject:aPagelet];
            [item setEditable:YES];
            
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

/*  Similar to NSTableView's concept of dropping above a given row
 */
- (NSUInteger)indexOfDrop:(id <NSDraggingInfo>)dragInfo
{
    NSUInteger result = NSNotFound;
    SVWebEditorView *editor = [self webEditorView];
    NSArray *pageletContentItems = [self contentItems];
    
    
    // Ideally, we're making a drop *before* a pagelet
    NSUInteger i, count = [pageletContentItems count];
    for (i = 0; i < count; i++)
    {
        SVWebEditorItem *aPageletItem = [pageletContentItems objectAtIndex:i];
    
        NSRect dropZone = [self rectOfDropZoneAboveDOMNode:[aPageletItem DOMElement]
                                                 minHeight:25.0f];
        
        if ([editor mouse:[editor convertPointFromBase:[dragInfo draggingLocation]] inRect:dropZone])
        {
            result = i;
            break;
        }
    }
    
    
    // If not, is it a drop *after* the last pagelet, or into an empty sidebar?
    if (result == NSNotFound)
    {
        NSRect dropZone = [self rectOfDropZoneInDOMElement:_sidebarDiv
                                                 belowNode:[[pageletContentItems lastObject] DOMElement]
                                                 minHeight:25.0f];
        
        if ([editor mouse:[editor convertPointFromBase:[dragInfo draggingLocation]] inRect:dropZone])
        {
            result = [pageletContentItems count];
        }
    }
    
    
    return result;
}

- (NSRect)rectOfDropZoneAboveDOMNode:(DOMNode *)node minHeight:(CGFloat)minHeight;
{
    NSRect nodeBox = [node boundingBox];
    
    DOMNode *previousNode = [node previousSibling];
    NSRect previousNodeBox = [previousNode boundingBox];
    
    NSRect result;
    if (previousNode && !NSEqualRects(previousNodeBox, NSZeroRect))
    {
        // Claim the space between the nodes
        result.origin.x = MIN(NSMinX(previousNodeBox), NSMinX(nodeBox));
        result.origin.y = NSMaxY(previousNodeBox);
        result.size.width = MAX(NSMaxX(previousNodeBox), NSMaxX(nodeBox)) - result.origin.x;
        result.size.height = NSMinY(nodeBox) - result.origin.y;
    }
    else
    {
        // Claim the strip at the top of the node
        result.origin.x = NSMinX(nodeBox);
        result.origin.y = NSMinY(nodeBox);
        result.size.width = nodeBox.size.width;
        result.size.height = 0.0f;
    }
    
    // It should be at least ? pixels tall
    if (result.size.height < minHeight)
    {
        result = NSInsetRect(result, 0.0f, -0.5 * (minHeight - result.size.height));
    }
    
    return [[self webEditorView] convertRect:result fromView:[node documentView]];
}

- (NSRect)rectOfDropZoneInDOMElement:(DOMElement *)element
                           belowNode:(DOMNode *)node
                           minHeight:(CGFloat)minHeight;
{
    //Normally equal to element's -boundingBox.
    NSRect result = [element boundingBox];
    
    
    //  But then shortened to only include the area below boundingBox
    if (node)
    {
        NSRect nodeBox = [node boundingBox];
        CGFloat nodeBottom = NSMaxY(nodeBox);
        
        result.size.height = NSMaxY(result) - nodeBottom;
        result.origin.y = nodeBottom;
    }
    
    
    //  Finally, expanded again to minHeight if needed.
    if (result.size.height < minHeight)
    {
        result = NSInsetRect(result, 0.0f, -0.5 * (minHeight - result.size.height));
    }
    
    
    return [[self webEditorView] convertRect:result fromView:[element documentView]];
}

#pragma mark Element Actions

- (void)insertPagelet:(id)sender;
{
    // Will expand this to insert within the text if appropriate
    [self insertPageletInSidebar:sender];
}

- (IBAction)insertPageletInSidebar:(id)sender;
{
    KTPage *page = [self page];
    
    
    // Create the pagelet
	SVPagelet *pagelet = [NSEntityDescription insertNewObjectForEntityForName:@"Pagelet"
													  inManagedObjectContext:[page managedObjectContext]];
	OBASSERT(pagelet);
    
    [pagelet setTitleHTMLString:@"Double-click to edit"];
    [[pagelet body] setArchiveHTMLString:@"Test"];
    
    
    // Place at end of the sidebar
    SVSidebar *sidebar = [page sidebar];
    SVPagelet *lastPagelet = [[SVPagelet arrayBySortingPagelets:[sidebar pagelets]] lastObject];
    [pagelet moveAfterPagelet:lastPagelet];
    
	[sidebar addPageletsObject:pagelet];
}

- (void)insertElement:(id)sender;
{
    // Create a new element of the requested type and insert into selected text block
    SVPageletBody *body = [[[self textAreaControllers] firstObjectKS] content];
    SVContentObject *element = [NSEntityDescription insertNewObjectForEntityForName:@"ContentObject"    
                                                             inManagedObjectContext:[body managedObjectContext]];
    [element setValue:[[[sender representedObject] bundle] bundleIdentifier] forKey:@"plugInIdentifier"];
    [element setContainer:body];
    [element awakeFromBundleAsNewlyCreatedObject:YES];
    
    
    [body setArchiveHTMLString:[[body archiveHTMLString] stringByAppendingString:[element archiveHTMLString]]];
}

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
    for (SVWebContentItem *item in items)
    {
        SVPagelet *pagelet = [item representedObject];
        [[pagelet managedObjectContext] deleteObject:pagelet];
    }
    
    return YES;
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
    else
    {
        [pasteboard declareTypes:[NSArray array] owner:self];
        result = YES;
    }
    
    
    return result;
}

/*  Want to leave the Web Editor View in charge of drag & drop except for pagelets
 */
- (NSDragOperation)webEditorView:(SVWebEditorView *)sender
      dataSourceShouldHandleDrop:(id <NSDraggingInfo>)dragInfo;
{
    OBPRECONDITION(sender == [self webEditorView]);
    
    NSDragOperation result = NSDragOperationNone;
    
    NSUInteger dropIndex = [self indexOfDrop:dragInfo];
    if (dropIndex != NSNotFound)
    {
        result = NSDragOperationMove;
        
        
        // Place the drag caret to match the drop index
        NSArray *pageletContentItems = [self contentItems];
        if (dropIndex >= [pageletContentItems count])
        {
            DOMNode *node = [_sidebarDiv lastChild];
            DOMRange *range = [[node ownerDocument] createRange];
            [range setStartAfter:node];
            [sender moveDragCaretToDOMRange:range];
        }
        else
        {
            SVWebEditorItem *aPageletItem = [pageletContentItems objectAtIndex:dropIndex];
            
            DOMRange *range = [[[aPageletItem DOMElement] ownerDocument] createRange];
            [range setStartBefore:[aPageletItem DOMElement]];
            [sender moveDragCaretToDOMRange:range];
        }
    }
    
    
    return result;
}

- (BOOL)webEditorView:(SVWebEditorView *)sender acceptDrop:(id <NSDraggingInfo>)dragInfo;
{
    OBPRECONDITION(sender == [self webEditorView]);
    BOOL result = NO;
    
    NSArray *pageletContentItems = [self contentItems];
    
    
    //  When dragging within the same view, want to move the selected pagelets
    //  Possibly bad, I'm assuming all selected items are pagelets
    if ([dragInfo draggingSource] == sender)
    {
        result = YES;
        
        NSUInteger dropIndex = [self indexOfDrop:dragInfo];
        if (dropIndex == NSNotFound)
        {
            result = NO;
        }
        else if (dropIndex >= [pageletContentItems count])
        {
            SVPagelet *lastPagelet = [[pageletContentItems lastObject] representedObject];
            for (SVWebContentItem *aPageletItem in [sender selectedItems])
            {
                SVPagelet *pagelet = [aPageletItem representedObject];
                [pagelet moveAfterPagelet:lastPagelet];
            }
        }
        else
        {
            for (SVWebContentItem *aPageletItem in [sender selectedItems])
            {
                SVPagelet *anchorPagelet = [[pageletContentItems objectAtIndex:dropIndex] representedObject];
                SVPagelet *pagelet = [aPageletItem representedObject];
                [pagelet moveBeforePagelet:anchorPagelet];
            }
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

