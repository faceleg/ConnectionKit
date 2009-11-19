//
//  SVWebEditorViewController.m
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorViewController.h"

#import "SVBodyParagraph.h"
#import "SVPlugInContentObject.h"
#import "SVHTMLTemplateParser.h"
#import "SVHTMLTextBlock.h"
#import "KTPage.h"
#import "SVPagelet.h"
#import "SVPageletBody.h"
#import "SVPageletBodyTextAreaController.h"
#import "KTSite.h"
#import "SVWebContentItem.h"
#import "SVSelectionBorder.h"
#import "SVSidebar.h"
#import "SVWebEditorHTMLContext.h"
#import "SVWebTextArea.h"

#import "DOMNode+Karelia.h"
#import "NSArray+Karelia.h"
#import "NSURL+Karelia.h"
#import "NSWorkspace+Karelia.h"

#import "KSCollectionController.h"
#import "KSSilencingConfirmSheet.h"


@interface SVWebEditorViewController ()
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


@implementation SVWebEditorViewController

#pragma mark Init & Dealloc

- (void)dealloc
{
    [self setWebEditorView:nil];   // needed to tear down data source
    
    [_page release];
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
    
    
    
    /// FIXME: THIS IS A HACK TO REMOVE
    if (webView)
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(webViewDidChange:) name:WebViewDidChangeNotification object:[self webView]];
}

- (void)webViewDidChange:(NSNotification *)notification
{
    [[self textAreaControllers] makeObjectsPerformSelector:@selector(commitEditing)];
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

#pragma mark Content

// Support
- (void)loadHTMLString:(NSString *)pageHTML;
{
    // Record that the webview is being loaded with content. Otherwise, the policy delegate will refuse requests.
    [self setLoading:YES];
    
    
    [_HTMLGenerationContext release], _HTMLGenerationContext = [[SVHTMLContext currentContext] retain];
    
    
	// Figure out the URL to use
	NSURL *pageURL = [[self page] URL];
    if (![pageURL scheme] ||        // case 44071: WebKit will not load the HTML or offer delegate
        ![pageURL host] ||          // info if the scheme is something crazy like fttp:
        !([[pageURL scheme] isEqualToString:@"http"] || [[pageURL scheme] isEqualToString:@"https"]))
    {
        pageURL = nil;
    }
    
    
    // Load the HTML into the webview
    [[self webEditorView] loadHTMLString:pageHTML baseURL:pageURL];
}

@synthesize loading = _isLoading;

- (void)webEditorViewDidFinishLoading:(SVWebEditorView *)sender;
{
    DOMDocument *domDoc = [[self webEditorView] DOMDocument];
    
    
    // Set up selection borders for all pagelets. Could we do this better by receiving a list of pagelets from the parser?
    NSArray *pagelets = [SVPagelet arrayBySortingPagelets:[[[self page] sidebar] pagelets]];
    NSMutableArray *contentObjects = [[NSMutableArray alloc] initWithCapacity:[pagelets count]];
    
    for (SVContentObject *aContentObject in [[self contentController] arrangedObjects])
    {
        DOMElement *element = [aContentObject DOMElementInDocument:domDoc];
        if (element)
        {
            SVWebContentItem *item = [[SVWebContentItem alloc] initWithDOMElement:element];
            [item setRepresentedObject:aContentObject];
            [item setEditable:YES];
            
            [contentObjects addObject:item];
            [item release];
        }
        else
        {
            NSLog(@"Could not locate content object with ID: %@", [aContentObject elementID]);
        }
    }
    
    [self setContentItems:contentObjects];
    [contentObjects release];
    
    
    
    // Prepare text areas and their controllers
    NSArray *parsedTextBlocks = [_HTMLGenerationContext generatedTextBlocks];
    NSMutableArray *textAreas = [[NSMutableArray alloc] initWithCapacity:[parsedTextBlocks count]];
    NSMutableArray *textAreaControllers = [[NSMutableArray alloc] init];
    
    for (SVHTMLTextBlock *aTextBlock in parsedTextBlocks)
    {
        // Basic text area
        DOMHTMLElement *element = (DOMHTMLElement *)[domDoc getElementById:[aTextBlock DOMNodeID]];
        if (element)
        {
            OBASSERT([element isKindOfClass:[DOMHTMLElement class]]);
            
            SVWebTextArea *textArea = [[SVWebTextArea alloc] initWithHTMLDOMElement:element];
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
        else
        {
            NSLog(@"Couldn't find text area: %@", [aTextBlock DOMNodeID]);
        }
    }
    
    [self setTextAreas:textAreas];
    [textAreas release];
    [self setTextAreaControllers:textAreaControllers];
    [textAreaControllers release];
    
    
    
    
    // Match selection to controller
    NSArray *selectedObjects = [[self contentController] selectedObjects];
    NSMutableArray *newSelection = [[NSMutableArray alloc] initWithCapacity:[selectedObjects count]];
    
    for (id anObject in selectedObjects)
    {
        id newItem = [self contentItemForObject:anObject];
        if (newItem) [newSelection addObject:newItem];
    }
    
    [[self webEditorView] setSelectedItems:newSelection];   // this will feed back to us and the controller in notification
    [newSelection release];
    
    
    
    
    // Locate the sidebar
    _sidebarDiv = [[domDoc getElementById:@"sidebar"] retain];
    
    
    // Mark as loaded
    [self setLoading:NO];
    
}

@synthesize page = _page;
@synthesize contentController = _contentController;

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
            if ([result HTMLDOMElement] == editableElement)
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

- (id <SVWebEditorItem>)contentItemForObject:(id)object;
{
    OBPRECONDITION(object);
    id result = nil;
    
    for (SVWebContentItem *anItem in [self contentItems])
    {
        if ([[anItem representedObject] isEqual:object])
        {
            result = anItem;
            break;
        }
    }
    
    return result;
}

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
    
    SVBodyParagraph *paragraph = [NSEntityDescription insertNewObjectForEntityForName:@"BodyParagraph" inManagedObjectContext:[page managedObjectContext]];
    [paragraph setTagName:@"p"];
    [paragraph setArchivedInnerHTMLString:@"Test"];
    [[pagelet pageletBody] addElement:paragraph];
    
    
    // Place at end of the sidebar
    SVSidebar *sidebar = [page sidebar];
    SVPagelet *lastPagelet = [[SVPagelet arrayBySortingPagelets:[sidebar pagelets]] lastObject];
    [pagelet moveAfterPagelet:lastPagelet];
    
	[sidebar addPageletsObject:pagelet];
}

- (void)insertElement:(id)sender;
{
    // Create a new element of the requested type and insert at the end of the pagelet
    SVPageletBody *body = [[[self textAreaControllers] firstObjectKS] content];
    
    SVPlugInContentObject *element = [NSEntityDescription insertNewObjectForEntityForName:@"PlugInContentObject"    
                                                             inManagedObjectContext:[body managedObjectContext]];
    
    [element setValue:[[[sender representedObject] bundle] bundleIdentifier] forKey:@"plugInIdentifier"];
    [element setWrap:SVContentObjectWrapNone];
    [element awakeFromBundleAsNewlyCreatedObject:YES];
    
    SVBodyElement *lastElement = [[body orderedElements] lastObject];
    [body addElement:element];
    [element insertAfterElement:lastElement];
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

- (BOOL)webEditorView:(SVWebEditorView *)sender shouldChangeSelection:(NSArray *)proposedSelectedItems;
{
    //  Update our content controller's selected objects to reflect the new selection in the Web Editor View
    
    OBPRECONDITION(sender == [self webEditorView]);
    
    // TODO: Can we do this without a cast?
    NSArray *objects = [proposedSelectedItems valueForKey:@"representedObject"];
    BOOL result = [(NSArrayController *)[self contentController] setSelectedObjects:objects];
    return result;
}

- (void)webEditorViewDidChangeSelection:(NSNotification *)notification; { }

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

