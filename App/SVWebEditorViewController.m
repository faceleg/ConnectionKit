//
//  SVWebEditorViewController.m
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorViewController.h"

#import "SVBodyParagraph.h"
#import "SVPlugInGraphic.h"
#import "SVHTMLTextBlock.h"
#import "KTPage.h"
#import "SVPagelet.h"
#import "SVPageletBody.h"
#import "SVBodyTextArea.h"
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
#import "KSOrderedManagedObjectControllers.h"
#import "KSSilencingConfirmSheet.h"


static NSString *sWebViewDependenciesObservationContext = @"SVWebViewDependenciesObservationContext";


@interface SVWebEditorViewController ()
@property(nonatomic, readwrite, getter=isLoading) BOOL loading;

@property(nonatomic, retain, readwrite) SVHTMLContext *HTMLContext;
@property(nonatomic, copy, readwrite) NSArray *textAreas;


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

- (id)init
{
    self = [super init];
    
    _selectableObjectsController = [[NSArrayController alloc] init];
    [_selectableObjectsController setAvoidsEmptySelection:NO];
    [_selectableObjectsController setObjectClass:[NSObject class]];
    
    return self;
}
    
- (void)dealloc
{
    [self setWebEditorView:nil];   // needed to tear down data source
    
    [_page release];
    [_textAreas release];
    [_context release];
    
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
    [editor setAllowsUndo:NO];  // will be managing this entirely ourselves
}

#pragma mark Loading

- (void)load;
{
	// Tear down old dependencies
    for (KSObjectKeyPathPair *aDependency in _pageDependencies)
    {
        [[aDependency object] removeObserver:self
                                  forKeyPath:[aDependency keyPath]];
    }
    
    
    // Build the HTML.
	SVWebEditorHTMLContext *context = [[SVWebEditorHTMLContext alloc] init];
    [context setCurrentPage:[self page]];
    [context setGenerationPurpose:kGeneratingPreview];
	/*[parser setIncludeStyling:([self viewType] != KTWithoutStylesView)];*/
    
    [SVHTMLContext pushContext:context];    // will pop after loading
	NSString *pageHTML = [[self page] HTMLString];
    [SVHTMLContext popContext];
    
    
    //  What are the selectable objects? Pagelets and other SVContentObjects
    NSMutableSet *selectableObjects = [[NSMutableSet alloc] init];
    [selectableObjects unionSet:[[[self page] sidebar] pagelets]];
    for (SVHTMLTextBlock *aTextBlock in [context generatedTextBlocks])
    {
        id content = [[aTextBlock HTMLSourceObject] valueForKeyPath:[aTextBlock HTMLSourceKeyPath]];
        if ([content isKindOfClass:[SVPageletBody class]])
        {
            //[selectableObjects unionSet:[content contentObjects]];
        }
    }
    
    [_selectableObjects release];
    _selectableObjects = selectableObjects;
    [_selectableObjectsController setContent:_selectableObjects];
	
    
    //  Start loading. Some parts of WebKit need to be attached to a window to work properly, so we need to provide one while it's loading in the
    //  background. It will be removed again after has finished since the webview will be properly part of the view hierarchy.
    
    [[self webView] setHostWindow:[[self view] window]];   // TODO: Our view may be outside the hierarchy too; it woud be better to figure out who our window controller is and use that.
    [self setHTMLContext:context];
    
    
    // Record that the webview is being loaded with content. Otherwise, the policy delegate will refuse requests.
    [self setLoading:YES];
    
    
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
    
    
    // Observe the used keypaths
    [_pageDependencies release], _pageDependencies = [[context dependencies] copy];
    for (KSObjectKeyPathPair *aDependency in _pageDependencies)
    {
        [[aDependency object] addObserver:self
                               forKeyPath:[aDependency keyPath]
                                  options:0
                                  context:sWebViewDependenciesObservationContext];
    }
    
    
    // Tidy up
    [context release];
    
	
    // Clearly the webview is no longer in need of refreshing
	_needsLoad = NO;
}

@synthesize loading = _isLoading;

- (void)webEditorViewDidFinishLoading:(SVWebEditorView *)sender;
{
    DOMDocument *domDoc = [[self webEditorView] HTMLDocument];
    
    
    // Set up selection borders for all pagelets. Could we do this better by receiving a list of pagelets from the parser?
    NSArray *pagelets = [SVPagelet arrayBySortingPagelets:[[[self page] sidebar] pagelets]];
    NSMutableArray *contentObjects = [[NSMutableArray alloc] initWithCapacity:[pagelets count]];
    
    for (SVGraphic *aContentObject in [[self selectedObjectsController] arrangedObjects])
    {
        DOMHTMLElement *element = (DOMHTMLElement *)[aContentObject elementForEditingInDOMDocument:domDoc];
        if (element)
        {
            SVWebContentItem *item = [[SVWebContentItem alloc] initWithHTMLElement:element];
            [item setRepresentedObject:aContentObject];
            [item setHTMLContext:[self HTMLContext]];
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
    
    
    
    // Prepare text areas
    NSArray *parsedTextBlocks = [[self HTMLContext] generatedTextBlocks];
    NSMutableArray *textAreas = [[NSMutableArray alloc] initWithCapacity:[parsedTextBlocks count]];
    
    for (SVHTMLTextBlock *aTextBlock in parsedTextBlocks)
    {
        DOMHTMLElement *element = (DOMHTMLElement *)[domDoc getElementById:[aTextBlock DOMNodeID]];
        if (element)
        {
            OBASSERT([element isKindOfClass:[DOMHTMLElement class]]);
            
            
            // Use the right sort of text area
            id textArea;
            id value = [[aTextBlock HTMLSourceObject] valueForKeyPath:[aTextBlock HTMLSourceKeyPath]];
            
            if ([value isKindOfClass:[SVPageletBody class]])
            {
                KSSetController *elementsController = [[KSSetController alloc] init];
                [elementsController setOrderingSortKey:@"sortKey"];
                [elementsController setManagedObjectContext:[[self page] managedObjectContext]];
                [elementsController setEntityName:@"BodyParagraph"];
                [elementsController setAutomaticallyRearrangesObjects:YES];
                [elementsController bind:NSContentSetBinding toObject:value withKeyPath:@"elements" options:nil];
                
                textArea = [[SVBodyTextArea alloc] initWithHTMLElement:element content:elementsController];
                [textArea setHTMLContext:[self HTMLContext]];
                [textArea setRichText:YES];
                [textArea setFieldEditor:NO];
                [textArea setEditable:YES];
                
                // Store as the body text of correct item
                SVWebEditorItem *item = [[self webEditorView] itemForDOMNode:element];
                [item setBodyText:textArea];
            }
            else
            {
                textArea = [[SVWebTextArea alloc] initWithHTMLElement:element];
                [textArea setHTMLContext:[self HTMLContext]];
                [textArea setRichText:[aTextBlock isRichText]];
                [textArea setFieldEditor:[aTextBlock isFieldEditor]];
                [textArea setEditable:[aTextBlock isEditable]];
                
                [textArea bind:NSValueBinding
                      toObject:[aTextBlock HTMLSourceObject]
                   withKeyPath:[aTextBlock HTMLSourceKeyPath]
                       options:nil];
            }
            
            [textAreas addObject:textArea];
            [textArea release];
        }
        else
        {
            NSLog(@"Couldn't find text area: %@", [aTextBlock DOMNodeID]);
        }
    }
    
    [self setTextAreas:textAreas];
    [textAreas release];
    
    
    
    
    // Match selection to controller
    NSArray *selectedObjects = [[self selectedObjectsController] selectedObjects];
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

@synthesize needsLoad = _needsLoad;
- (void)setNeedsLoad;
{
    if (![self needsLoad])
	{
		// Install a fresh observer for the end of the run loop
		[[NSRunLoop currentRunLoop] performSelector:@selector(load)
                                             target:self
                                           argument:nil
                                              order:0
                                              modes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
	}
	
    _needsLoad = YES;
}

- (void)loadIfNeeded { if ([self needsLoad]) [self load]; }

#pragma mark Content

@synthesize selectedObjectsController = _selectableObjectsController;

@synthesize HTMLContext = _context;

@synthesize page = _page;
- (void)setPage:(KTPage *)page
{
    [page retain];
    [_page release];
    _page = page;
    
    [self load];
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
            if ([result HTMLElement] == editableElement)
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
    [paragraph setInnerHTMLArchiveString:@"Test"];
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
    SVPageletBody *body = [(SVPagelet *)[[[[self page] sidebar] pagelets] anyObject] pageletBody];
    
    SVPlugInGraphic *element = [NSEntityDescription insertNewObjectForEntityForName:@"PlugInGraphic"    
                                                             inManagedObjectContext:[body managedObjectContext]];
    
    [element setValue:[[[sender representedObject] bundle] bundleIdentifier] forKey:@"plugInIdentifier"];
    [element setWrap:SVContentObjectWrapNone];
    [element awakeFromBundleAsNewlyCreatedObject:YES];
    
    [body addElement:element];
}

#pragma mark Delegate

@synthesize delegate = _delegate;

#pragma mark -

#pragma mark WebEditorViewDataSource

- (NSArray *)webEditorView:(SVWebEditorView *)sender childrenOfItem:(id)item;
{
    NSArray *result = nil;
    
    if (item)
    {
        result = [[item bodyText] contentItems];  
    }
    else
    {
        result = [self contentItems];
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

- (void)webEditorViewDidFirstLayout:(SVWebEditorView *)sender;
{
    OBPRECONDITION(sender == [self webEditorView]);
    [[self delegate] webEditorViewControllerDidFirstLayout:self];
}

- (BOOL)webEditorView:(SVWebEditorView *)sender shouldChangeSelection:(NSArray *)proposedSelectedItems;
{
    //  Update our content controller's selected objects to reflect the new selection in the Web Editor View
    
    OBPRECONDITION(sender == [self webEditorView]);
    
    // TODO: Can we do this without a cast?
    NSArray *objects = [proposedSelectedItems valueForKey:@"representedObject"];
    BOOL result = [(NSArrayController *)[self selectedObjectsController] setSelectedObjects:objects];
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

#pragma mark -

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == sWebViewDependenciesObservationContext)
    {
        [self setNeedsLoad];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end

