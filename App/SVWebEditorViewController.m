//
//  SVWebEditorViewController.m
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorViewController.h"

#import "SVApplicationController.h"
#import "SVAttributedHTML.h"
#import "SVPlugInGraphic.h"
#import "KTElementPlugInWrapper+DataSourceRegistration.h"
#import "SVLogoImage.h"
#import "KTMaster.h"
#import "KTPage.h"
#import "SVGraphic.h"
#import "SVRichTextDOMController.h"
#import "SVHTMLContext.h"
#import "SVLink.h"
#import "SVLinkManager.h"
#import "SVMediaRecord.h"
#import "KTSite.h"
#import "SVSelectionBorder.h"
#import "SVSidebar.h"
#import "SVWebContentObjectsController.h"
#import "SVWebEditorHTMLContext.h"
#import "KTDocument.h"

#import "DOMNode+Karelia.h"
#import "NSArray+Karelia.h"
#import "NSURL+Karelia.h"
#import "NSWorkspace+Karelia.h"

#import "KSCollectionController.h"
#import "KSPlugInWrapper.h"
#import "KSSilencingConfirmSheet.h"

#import <BWToolkitFramework/BWToolkitFramework.h>


NSString *sSVWebEditorViewControllerWillUpdateNotification = @"SVWebEditorViewControllerWillUpdateNotification";
static NSString *sWebViewDependenciesObservationContext = @"SVWebViewDependenciesObservationContext";


@interface SVWebEditorViewController ()

@property(nonatomic, readwrite) BOOL viewIsReadyToAppear;

@property(nonatomic, readwrite, getter=isUpdating) BOOL updating;

@property(nonatomic, retain, readwrite) SVWebEditorHTMLContext *HTMLContext;

@property(nonatomic, retain, readonly) SVWebContentObjectsController *primitiveSelectedObjectsController;

// Pagelets
@property(nonatomic, copy, readwrite) NSArray *sidebarPageletItems;
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
    
    _selectableObjectsController = [[SVWebContentObjectsController alloc] init];
    [_selectableObjectsController setAvoidsEmptySelection:NO];
    [_selectableObjectsController setObjectClass:[NSObject class]];
    
    _textDOMControllers = [[NSMutableArray alloc] init];
    
    return self;
}
    
- (void)dealloc
{
    [[[self webEditor] undoManager] removeAllActionsWithTarget:self];
    
    [self setWebEditor:nil];   // needed to tear down data source
    [self setDelegate:nil];
    
    [_page release];
    [_textDOMControllers release];
    [_context release];
    
    [super dealloc];
}

#pragma mark Views

- (void)loadView
{
    SVWebEditorView *editor = [[SVWebEditorView alloc] init];
    
    [self setView:editor];
    [self setWebEditor:editor];
    [self setWebView:[editor webView]];
    
    // Keep links beahviour in sync with the defaults
    [editor bind:@"liveEditableAndSelectableLinks"
        toObject:[NSUserDefaultsController sharedUserDefaultsController]
     withKeyPath:[@"values." stringByAppendingString:kLiveEditableAndSelectableLinksDefaultsKey]
         options:nil];
    
    // Register the editor for drag & drop
    [editor registerForDraggedTypes:[NSArray arrayWithObject:kKTPageletsPboardType]];
    
    [editor release];
}

- (void)setWebView:(WebView *)webView
{
    // Store new webview
    [super setWebView:webView];
}

@synthesize webEditor = _webEditorView;
- (void)setWebEditor:(SVWebEditorView *)editor
{
    [[self webEditor] setDelegate:nil];
    [[self webEditor] setDataSource:nil];
    
    [editor retain];
    [_webEditorView release];
    _webEditorView = editor;
    
    [editor setDelegate:self];
    [editor setDataSource:self];
    [editor setAllowsUndo:NO];  // will be managing this entirely ourselves
}

#pragma mark Presentation

@synthesize viewIsReadyToAppear = _readyToAppear;

- (void)webViewDidFirstLayout
{
    // Being a little bit cunning to make sure we sneak in before views can be drawn
    [[NSRunLoop currentRunLoop] performSelector:@selector(switchToLoadingPlaceholderViewIfNeeded)
                                         target:self
                                       argument:nil
                                          order:(NSDisplayWindowRunLoopOrdering - 1)
                                          modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
}

- (void)switchToLoadingPlaceholderViewIfNeeded
{
    // This method will be called fractionally after the webview has done its first layout, and (hopefully!) before that layout has actually been drawn. Therefore, if the webview is still loading by this point, it was an intermediate load and not suitable for display to the user, so switch over to the placeholder.
    if ([self isUpdating]) 
    {
        [self setViewIsReadyToAppear:NO];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    if (![self isUpdating]) [self loadSiteItem:nil];
    
    // Once we move offsreen, we're no longer suitable to be shown
    [self setViewIsReadyToAppear:NO];
}

#pragma mark Loading

/*  Loading is to Updating as Drawing is to Displaying (in NSView)
 */

- (void)loadWebEditor
{
    // Tear down old dependencies
    for (KSObjectKeyPathPair *aDependency in _pageDependencies)
    {
        [[aDependency object] removeObserver:self
                                  forKeyPath:[aDependency keyPath]];
    }
    
    // And DOM controllers.
    [[[self webEditor] mainItem] setChildWebEditorItems:nil];
    [_textDOMControllers removeAllObjects];
    
    
    // Build the HTML.
    NSMutableString *pageHTML = [[NSMutableString alloc] init];
	SVWebEditorHTMLContext *context = [[SVWebEditorHTMLContext alloc] initWithStringWriter:pageHTML];
    
    [context setCurrentPage:[self page]];
    [context setGenerationPurpose:kSVHTMLGenerationPurposeEditing];
    [context setLiveDataFeeds:[[NSUserDefaults standardUserDefaults] boolForKey:@"LiveDataFeeds"]];
    
    [SVHTMLContext pushContext:context];    // will pop after loading
	[[self page] writeHTML];
    [SVHTMLContext popContext];
    
    
    //  Start loading. Some parts of WebKit need to be attached to a window to work properly, so we need to provide one while it's loading in the
    //  background. It will be removed again after has finished since the webview will be properly part of the view hierarchy.
    
    [[self webView] setHostWindow:[[self view] window]];   // TODO: Our view may be outside the hierarchy too; it woud be better to figure out who our window controller is and use that.
    [self setHTMLContext:context];
    
    
    // Record that the webview is being loaded with content. Otherwise, the policy delegate will refuse requests. Also record location
    [self setUpdating:YES];
    _visibleRect = [[[self webEditor] documentView] visibleRect];
    
    
	// Figure out the URL to use
	NSURL *pageURL = [[self page] URL];
    if (![pageURL scheme] ||        // case 44071: WebKit will not load the HTML or offer delegate
        ![pageURL host] ||          // info if the scheme is something crazy like fttp:
        !([[pageURL scheme] isEqualToString:@"http"] || [[pageURL scheme] isEqualToString:@"https"]))
    {
        pageURL = nil;
    }
    
    
    // Load the HTML into the webview
    [[self webEditor] loadHTMLString:pageHTML baseURL:pageURL];
    
    
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
    [pageHTML release];
}

- (void)webEditorViewDidFinishLoading:(SVWebEditorView *)sender;
{
    SVWebEditorView *webEditor = [self webEditor];
    DOMDocument *domDoc = [webEditor HTMLDocument];
    
    
    // Context holds the controllers. We need to send them over to the Web Editor.
    NSArray *controllers = [[self HTMLContext] webEditorItems];
    NSMutableArray *sidebarPageletItems = [[NSMutableArray alloc] init];
    
    NSMutableArray *selectableObjects = [[NSMutableArray alloc] initWithCapacity:[controllers count]];
    
    for (SVWebEditorItem *anItem in controllers)
    {
        // Insert into the tree if a top-level item
        if (![anItem parentWebEditorItem]) [[webEditor mainItem] addChildWebEditorItem:anItem];
        
        // Cheat and figure out if it's a sidebar pagelet controller
        id anObject = [anItem representedObject];
        if ([anObject isKindOfClass:[NSManagedObject class]] &&
            [anObject respondsToSelector:@selector(sidebars)] &&
            [[anObject sidebars] count] > 0)
        {
            [sidebarPageletItems addObject:anItem];
        }
    }
    
    [self setSidebarPageletItems:sidebarPageletItems];
    [sidebarPageletItems release];
        
    [_selectableObjectsController setPage:[self page]];         // do NOT set the controller's MOC. Unless you set both MOC
    [_selectableObjectsController setContent:selectableObjects];// and entity name, saving will raise an exception. (crazy I know!)
    [selectableObjects release];
    
    
    
    
    // Match selection to controller
    NSArray *selectedObjects = [[self selectedObjectsController] selectedObjects];
    NSMutableArray *newSelection = [[NSMutableArray alloc] initWithCapacity:[selectedObjects count]];
    
    for (id anObject in selectedObjects)
    {
        id newItem = [[[self webEditor] mainItem] descendantItemWithRepresentedObject:anObject];
        if ([newItem isSelectable]) [newSelection addObject:newItem];
    }
    
    [[self webEditor] setSelectedItems:newSelection];   // this will feed back to us and the controller in notification
    [newSelection release];
    
    
    
    
    // Locate the sidebar
    _sidebarDiv = [[domDoc getElementById:@"sidebar"] retain];
    
    
    // Restore scroll point
    [[self webEditor] scrollToPoint:_visibleRect.origin];
    
    
    // Mark as loaded
    [self setUpdating:NO];
    [self setViewIsReadyToAppear:YES];
    
    
    // Did Update
    [self didUpdate];
}

#pragma mark Updating

- (void)update;
{
	[self willUpdate];
    
	[self loadWebEditor];
	
    // Clearly the webview is no longer in need of refreshing
    _willUpdate = NO;
	_needsUpdate = NO;
}

@synthesize updating = _isUpdating;

- (void)scheduleUpdate
{
    // Ignore if Web Editor is dragging
    if ([[[self webEditor] draggedItems] count] > 0) return;
    
    // Private method known only to our Main DOM Controller. Schedules an update if needed.
    if (!_willUpdate)
	{
		// Install a fresh observer for the end of the run loop
		[[NSRunLoop currentRunLoop] performSelector:@selector(updateIfNeeded)
                                             target:self
                                           argument:nil
                                              order:0
                                              modes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
	}
    _willUpdate = YES;
}

@synthesize needsUpdate = _needsUpdate;
- (void)setNeedsUpdate;
{
    _needsUpdate = YES;
    
    [self scheduleUpdate];
}

- (void)updateIfNeeded
{
    if (!_willUpdate) return;   // don't you waste my time sucker!
    	
    if ([self needsUpdate])
    {
        [self update];
    }
    else
    {
        [[[self webEditor] mainItem] updateIfNeeded];
        _willUpdate = NO;
        
        [self didUpdate];
    }
}

- (IBAction)reload:(id)sender { [self setNeedsUpdate]; }

@synthesize autoupdate = _autoupdate;
- (void)setAutoupdate:(BOOL)autoupdate;
{
    _autoupdate = autoupdate;
}

- (void)willUpdate;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:sSVWebEditorViewControllerWillUpdateNotification object:self];   // -update also posts this
    
}

- (void)didUpdate;
{
    // Restore selection
    if (_selectionToRestore)
    {
        [[self webEditor] setSelectedTextRange:_selectionToRestore affinity:NSSelectionAffinityDownstream];
        [_selectionToRestore release]; _selectionToRestore = nil;
    }
}

#pragma mark Content

@synthesize primitiveSelectedObjectsController = _selectableObjectsController;
- (id <KSCollectionController>)selectedObjectsController
{
    return [self primitiveSelectedObjectsController];
}

- (SVTextDOMController *)focusedTextController
{
    return (SVTextDOMController *)[[self webEditor] focusedText];
}

+ (NSSet *)keyPathsForValuesAffectingFocusedTextController
{
    return [NSSet setWithObject:@"webEditor.focusedText"];
}

@synthesize HTMLContext = _context;

@synthesize page = _page;
- (void)setPage:(KTPage *)page
{
    if (page != _page)
    {
        [_page release]; _page = [page retain];
    
        [self update];
    }
}

- (void)registerWebEditorItem:(SVWebEditorItem *)item;  // recurses through, registering descendants too
{
    // Ensure element is loaded
    DOMDocument *domDoc = [[self webEditor] HTMLDocument];
    if (![item isHTMLElementCreated]) [item loadHTMLElementFromDocument:domDoc];
    OBASSERT([item HTMLElement]);
    
    
    // Figure out if it's a text controller
    if ([item isKindOfClass:[SVTextDOMController class]])
    {
        [_textDOMControllers addObject:item];
    }
    
    
    //  Populate controller with content. For now, this is simply all the represented objects of all the DOM controllers
    id anObject = [item representedObject];
    if (anObject) [_selectableObjectsController addObject:anObject];
    
    
    // Register descendants
    for (SVWebEditorItem *anItem in [item childWebEditorItems])
    {
        [self registerWebEditorItem:anItem];
    }
}

#pragma mark Text Areas

- (NSArray *)textAreas { return [[_textDOMControllers copy] autorelease]; }

- (SVTextDOMController *)textAreaForDOMNode:(DOMNode *)node;
{
    SVTextDOMController *result = nil;
    DOMHTMLElement *editableElement = [node enclosingContentEditableElement];
    
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

- (SVTextDOMController *)textAreaForDOMRange:(DOMRange *)range;
{
    // One day there might be better logic to apply, but for now, testing the start of the range is enough
    return [self textAreaForDOMNode:[range startContainer]];
}

#pragma mark Sidebar

@synthesize sidebarPageletItems = _sidebarPageletItems;

/*  Similar to NSTableView's concept of dropping above a given row
 */
- (NSUInteger)indexOfDrop:(id <NSDraggingInfo>)dragInfo
{
    NSUInteger result = NSNotFound;
    SVWebEditorView *editor = [self webEditor];
    NSArray *pageletContentItems = [self sidebarPageletItems];
    
    
    // Ideally, we're making a drop *before* a pagelet
    NSUInteger i, count = [pageletContentItems count];
    for (i = 0; i < count; i++)
    {
        SVWebEditorItem *aPageletItem = [pageletContentItems objectAtIndex:i];
    
        NSRect dropZone = [self rectOfDropZoneAboveDOMNode:[aPageletItem HTMLElement]
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
                                                 belowNode:[[pageletContentItems lastObject] HTMLElement]
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
    
    return [[self webEditor] convertRect:result fromView:[node documentView]];
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
    
    
    return [[self webEditor] convertRect:result fromView:[element documentView]];
}

#pragma mark Element Insertion

- (void)_insertPageletInSidebar:(SVGraphic *)pagelet;
{
    // Place at end of the sidebar
    [[_selectableObjectsController sidebarPageletsController] addObject:pagelet];
}

- (IBAction)insertPagelet:(id)sender;
{
    if (![self tryToMakeSelectionPerformAction:_cmd with:sender])
    {
        [self insertPageletInSidebar:sender];
    }
}

- (IBAction)insertPageletInSidebar:(id)sender;
{
    // Create element
    KTPage *page = [self page];
    
    SVGraphic *pagelet;
    if ([sender respondsToSelector:@selector(representedObject)] && [sender representedObject])
    {
        NSString *identifier = [[[sender representedObject] bundle] bundleIdentifier];
        
        pagelet = [SVPlugInGraphic insertNewGraphicWithPlugInIdentifier:identifier
                                                 inManagedObjectContext:[page managedObjectContext]];
    }
    else
    {
        pagelet = [[_selectableObjectsController newPagelet] autorelease];
    }
    
    
    // Insert it
    [pagelet awakeFromInsertIntoPage:page];
    [self _insertPageletInSidebar:pagelet];
}

- (IBAction)insertElement:(id)sender;
{
    if (![self tryToMakeSelectionPerformAction:_cmd with:sender])
    {
        [self insertPageletInSidebar:sender];
    }
}

- (IBAction)insertFile:(id)sender;
{
    if (![self tryToMakeSelectionPerformAction:_cmd with:sender])
    {
        NSWindow *window = [[self view] window];
        NSOpenPanel *panel = [[[window windowController] document] makeChooseDialog];
        
        [panel beginSheetForDirectory:nil file:nil modalForWindow:window modalDelegate:self didEndSelector:@selector(chooseDialogDidEnd:returnCode:contextInfo:) contextInfo:NULL];
    }
}

- (void)chooseDialogDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    if (returnCode == NSCancelButton) return;
    
    
    NSManagedObjectContext *context = [[self page] managedObjectContext];
    SVMediaRecord *media = [SVMediaRecord mediaWithURL:[sheet URL]
                                            entityName:@"ImageMedia"
                        insertIntoManagedObjectContext:context
                                                 error:NULL];
    
    if (media)
    {
        SVImage *image = [SVImage insertNewImageWithMedia:media];
        [self _insertPageletInSidebar:image];
        [image awakeFromInsertIntoPage:[self page]];
    }
    else
    {
        NSBeep();
    }
}

#pragma mark Special Insertion

- (void)insertPageletTitle:(id)sender;
{
    // Give the selected pagelets a title if needed
    for (id anObject in [[self selectedObjectsController] selectedObjects])
    {
        if ([anObject isKindOfClass:[SVGraphic class]])
        {
            SVGraphic *pagelet = (SVGraphic *)anObject;
            if ([[[pagelet titleBox] text] length] <= 0)
            {
                [pagelet setTitle:[[pagelet class] placeholderTitleText]];
            }
        }
    }
}

#pragma mark Action Forwarding

- (BOOL)tryToMakeSelectionPerformAction:(SEL)action with:(id)anObject;
{
    DOMRange *selection = [[self webEditor] selectedDOMRange];
    SVTextDOMController *text = [self textAreaForDOMRange:selection];
    return [text tryToPerform:action with:anObject];
}

#pragma mark Undo

- (void)undo_setSelectedTextRange:(SVWebEditorTextRange *)range;
{
    // Ignore if not already marked for update, since that could potentially reset the selection in the distant future, which is very odd for users. Ideally, this situation won't arrive
    if (![self needsUpdate]) return;
    
    
    [_selectionToRestore release]; _selectionToRestore = [range copy];
    
    // Push opposite onto undo stack
    SVWebEditorView *webEditor = [self webEditor];
    NSUndoManager *undoManager = [webEditor undoManager];
    
    [[undoManager prepareWithInvocationTarget:self]
     undo_setSelectedTextRange:[webEditor selectedTextRange]];
}

- (void)textDOMControllerDidChangeText:(SVTextDOMController *)controller; { }

#pragma mark UI Validation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem;
{
    BOOL result = YES;
    
    if (result)
    {
        SEL action = [menuItem action];
        
        if (action == @selector(insertSiteTitle:))
        {
            //  Can insert site title if there isn't already one
            result = ([[[[[self page] master] siteTitle] text] length] == 0);
        }
        else if (action == @selector(insertSiteSubtitle:))
        {
            //  Can insert site title if there isn't already one
            result = ([[[[[self page] master] siteSubtitle] text] length] == 0);
        }
        else if (action == @selector(insertPageTitle:))
        {
            //  Can insert site title if there isn't already one
            result = ([[[[self page] titleBox] text] length] == 0);
        }
        else if (action == @selector(insertPageletTitle:))
        {
            // To insert a pagelet title, the selection just needs to contain at least one title-less pagelet. #56871
            result = NO;
            for (id <NSObject> anObject in [[self selectedObjectsController] selectedObjects])
            {
                if ([anObject isKindOfClass:[SVGraphic class]])
                {
                    if ([[[(SVGraphic *)anObject titleBox] text] length] == 0)
                    {
                        result = YES;
                        break;
                    }
                }
            }
        }
        else if (action == @selector(insertFooter:))
        {
            //  Can insert site title if there isn't already one
            result = ([[[[[self page] master] footer] text] length] == 0);
        }
    }
              
    
    return result;
}

#pragma mark Delegate

@synthesize delegate = _delegate;
- (void)setDelegate:(id <SVWebEditorViewControllerDelegate>)delegate;
{
    if (_delegate)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:_delegate name:sSVWebEditorViewControllerWillUpdateNotification object:self];
    }
    
    _delegate = delegate;
    
    if ([delegate respondsToSelector:@selector(webEditorViewControllerWillUpdate:)])
    {
        [[NSNotificationCenter defaultCenter] addObserver:delegate
                                                 selector:@selector(webEditorViewControllerWillUpdate:)
                                                     name:sSVWebEditorViewControllerWillUpdateNotification
                                                   object:self];
    }
}

#pragma mark -

#pragma mark SVSiteItemViewController

- (void)loadSiteItem:(SVSiteItem *)item;
{
    [self setPage:[item pageRepresentation]];
}

#pragma mark -

#pragma mark WebEditorViewDataSource

- (SVWebEditorItem <SVWebEditorText> *)webEditor:(SVWebEditorView *)sender
                            textBlockForDOMRange:(DOMRange *)range;
{
    return [self textAreaForDOMRange:range];
}

- (BOOL)webEditor:(SVWebEditorView *)sender deleteItems:(NSArray *)items;
{
    NSArray *objects = [items valueForKey:@"representedObject"];
    if ([objects isEqualToArray:[_selectableObjectsController selectedObjects]])
    {
        [_selectableObjectsController remove:self];
    }
    else
    {
        [_selectableObjectsController removeObjects:objects];
    }
    
    return YES;
}

- (BOOL)webEditor:(SVWebEditorView *)sender addSelectionToPasteboard:(NSPasteboard *)pasteboard;
{
    BOOL result = NO;
    SVTextDOMController *textController = [self focusedTextController];
    
    
    if (textController)
    {
        [textController addSelectionTypesToPasteboard:pasteboard];
        return YES;
    }
    else
    {
        result = YES;
        
        // Want serialized pagelets on pboard
        SVAttributedHTML *attributedHTML = [[SVAttributedHTML alloc] init];
        
        
        // Want HTML of pagelets on pboard
        NSMutableString *html = [[NSMutableString alloc] init];
        SVHTMLContext *context = [[SVHTMLContext alloc] initWithStringWriter:html];
        [context setGenerationPurpose:kSVHTMLGenerationPurposeNormal];
        [context push];
        
        
        NSArray *items = [sender selectedItems];
        for (SVWebEditorItem *anItem in items)
        {
            // Give up if the selection contains a non-graphic
            SVGraphic *graphic = [anItem representedObject];
            if (![graphic isKindOfClass:[SVGraphic class]])
            {
                break;
                result = NO;
            }
            
            
            // Add the attachment to the custom HTML
            NSAttributedString *attachmentString = [SVAttributedHTML attributedHTMLWithAttachment:graphic];
            [attributedHTML appendAttributedString:attachmentString];
            
            
            // HTML representation of the item
            [(SVDOMController *)anItem writeRepresentedObjectHTML];
        }
        
        
        // Place serialized pagelets on pboard
        [pasteboard addTypes:[NSArray arrayWithObject:@"com.karelia.html+graphics"] owner:self];
        [attributedHTML writeToPasteboard:pasteboard];
        [attributedHTML release];
        
        
        // Place HTML on pasteboard
        [context pop];
        [context release];
        
        [pasteboard setString:html forType:NSHTMLPboardType];
        [html release];
        [pasteboard addTypes:[NSArray arrayWithObject:NSHTMLPboardType] owner:self];
    }
    
    
    
    return result;
}

/*  Want to leave the Web Editor View in charge of drag & drop except for pagelets
 */
- (NSDragOperation)webEditor:(SVWebEditorView *)sender
      dataSourceShouldHandleDrop:(id <NSDraggingInfo>)dragInfo;
{
    OBPRECONDITION(sender == [self webEditor]);
    
    NSDragOperation result = NSDragOperationNone;
    
    NSUInteger dropIndex = [self indexOfDrop:dragInfo];
    if (dropIndex != NSNotFound)
    {
        result = NSDragOperationMove;
        
        
        // Place the drag caret to match the drop index
        NSArray *pageletContentItems = [self sidebarPageletItems];
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
            
            DOMRange *range = [[[aPageletItem HTMLElement] ownerDocument] createRange];
            [range setStartBefore:[aPageletItem HTMLElement]];
            [sender moveDragCaretToDOMRange:range];
        }
    }
    else
    {
        // Don't allow drops of pagelets inside non-page body text.
        if ([dragInfo draggingSource] == sender && [[sender draggedItems] count])
        {
            NSDictionary *element = [[sender webView] elementAtPoint:[sender convertPointFromBase:[dragInfo draggingLocation]]];
            DOMNode *node = [element objectForKey:WebElementDOMNodeKey];
            
            if (![[[[[self textAreaForDOMNode:node] representedObject] entity] name]
                  isEqualToString:@"PageBody"])
            {
                result = YES;
            }
        }
    }
    
    
    return result;
}

- (BOOL)webEditor:(SVWebEditorView *)sender acceptDrop:(id <NSDraggingInfo>)dragInfo;
{
    OBPRECONDITION(sender == [self webEditor]);
    
    
    NSUInteger dropIndex = [self indexOfDrop:dragInfo];
    if (dropIndex == NSNotFound) return NO;
    
    
    BOOL result = NO;
    
    
    //  When dragging within the sidebar, want to move the selected pagelets
    if ([dragInfo draggingSource] == sender)
    {
        NSArray *sidebarPageletControllers = [self sidebarPageletItems];
        for (SVDOMController *aPageletItem in [sender selectedItems])
        {
            if ([sidebarPageletControllers containsObjectIdenticalTo:aPageletItem])
            {
                result = YES;
                
                SVGraphic *pagelet = [aPageletItem representedObject];
                [[_selectableObjectsController sidebarPageletsController] insertObject:pagelet
                                                                 atArrangedObjectIndex:dropIndex];
            }
        }
    }
    
    
    if (!result)
    {
        // Fallback to inserting a new pagelet from the pasteboard
        NSManagedObjectContext *moc = [[self page] managedObjectContext];
        NSPasteboard *pasteboard = [dragInfo draggingPasteboard];
        
        NSArray *pagelets = [SVAttributedHTML pageletsFromPasteboard:pasteboard
                                      insertIntoManagedObjectContext:moc];
        

        // Fallback to generic pasteboard support
        if ([pagelets count] < 1)
        {
            pagelets = [KTElementPlugInWrapper insertNewGraphicsWithPasteboard:pasteboard
                                                        inManagedObjectContext:moc];
        }
        
        for (SVGraphic *aPagelet in pagelets)
        {
            result = YES;
            [[_selectableObjectsController sidebarPageletsController] insertObject:aPagelet
                                                             atArrangedObjectIndex:dropIndex];
        }
    }
    
    return result;
}

#pragma mark SVWebEditorViewDelegate

- (void)webEditorViewDidFirstLayout:(SVWebEditorView *)sender;
{
    OBPRECONDITION(sender == [self webEditor]);
    [self webViewDidFirstLayout];
}

- (BOOL)webEditor:(SVWebEditorView *)sender shouldChangeSelection:(NSArray *)proposedSelectedItems;
{
    //  Update our content controller's selected objects to reflect the new selection in the Web Editor View
    
    OBPRECONDITION(sender == [self webEditor]);
    
    // HACK: Ignore these messages while loading as we'll sort out selection once the load is done
    BOOL result = YES;
    if (![self isUpdating])
    {
        NSArray *objects = [proposedSelectedItems valueForKey:@"representedObject"];
        result = [_selectableObjectsController setSelectedObjects:objects insertIfNeeded:YES];
    }
    
    return result;
}

- (void)webEditorViewDidChangeSelection:(NSNotification *)notification;
{
    if (![[self webEditor] selectedDOMRange])
    {
        SVLink *link = [_selectableObjectsController valueForKeyPath:@"selection.link"];
        
        if (NSIsControllerMarker(link))
        {
            [[SVLinkManager sharedLinkManager] setSelectedLink:nil
                                                      editable:(link == NSMultipleValuesMarker)];
        }
        else
        {
            [[SVLinkManager sharedLinkManager] setSelectedLink:link editable:YES];
        }
    }
}

- (BOOL)webEditor:(SVWebEditorView *)sender createLink:(SVLinkManager *)actionSender;
{
    if (![sender selectedDOMRange])
    {
        SVLink *link = [actionSender selectedLink];
        [_selectableObjectsController setValue:link forKeyPath:@"selection.link"];
        return YES;
    }
    
    return NO;
}

- (void)webEditor:(SVWebEditorView *)sender didReceiveTitle:(NSString *)title;
{
    [self setTitle:title];
}

- (NSURLRequest *)webEditor:(SVWebEditorView *)sender
            willSendRequest:(NSURLRequest *)request
           redirectResponse:(NSURLResponse *)redirectResponse
             fromDataSource:(WebDataSource *)dataSource;
{
    // Force the WebView to dump its cached resources from the WebDataSource so that any change to main.css gets picked up
    if ([[request mainDocumentURL] isEqual:[request URL]])
    {
        for (SVMediaRecord *aMediaRecord in [[self HTMLContext] media])
        {
            WebResource *resource = [aMediaRecord webResource];
            if (resource) [dataSource addSubresource:resource];
        }
        
        NSMutableURLRequest *result = [[request mutableCopy] autorelease];
        [result setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
        return result;
    }    
    
    
    // Preload main CSS
    if ([[request URL] ks_isEqualToURL:[[self HTMLContext] mainCSSURL]])
    {
        SVHTMLContext *context = [self HTMLContext];
        NSData *data = [[context mainCSS] dataUsingEncoding:NSUTF8StringEncoding];
        CFStringRef charSet = CFStringConvertEncodingToIANACharSetName(kCFStringEncodingUTF8);
        
        WebResource *resource = [[WebResource alloc] initWithData:data
                                                              URL:[request URL]
                                                         MIMEType:@"text/css"
                                                 textEncodingName:(NSString *)charSet
                                                        frameName:nil];
        [dataSource addSubresource:resource];
        [resource release];
    }
    
    return request;
}

- (void)webEditor:(SVWebEditorView *)sender handleNavigationAction:(NSDictionary *)actionInfo request:(NSURLRequest *)request;
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

- (void)webEditorWillChange:(NSNotification *)notification;
{
    SVWebEditorView *webEditor = [self webEditor];
    NSUndoManager *undoManager = [webEditor undoManager];
    
    // There's no point recording the action if registration is disabled. Especially since grabbing the selection is a relatively expensive op
    if ([undoManager isUndoRegistrationEnabled])
    {
        [[undoManager prepareWithInvocationTarget:self] 
         undo_setSelectedTextRange:[webEditor selectedTextRange]];
    }
}

- (void)webEditor:(SVWebEditorView *)sender didAddItem:(SVWebEditorItem *)item;
{
    OBPRECONDITION(sender == [self webEditor]);
    [self registerWebEditorItem:item];
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
        [self setNeedsUpdate];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end


#pragma mark -


@implementation SVWebEditorView (SVWebEditorViewController)

// Presently, SVWebEditorView doesn't implement paste directly itself, so we can jump in here
- (IBAction)paste:(id)sender;
{
    SVWebEditorViewController *controller = (id)[self dataSource];
    
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSManagedObjectContext *context = [[controller page] managedObjectContext];
    OBASSERT(context);
    
    NSArray *pagelets = [SVAttributedHTML pageletsFromPasteboard:pasteboard
                                                 insertIntoManagedObjectContext:context];
    
    if ([pagelets count])
    {
        SVSidebarPageletsController *sidebarPageletsController = [(id)[controller selectedObjectsController] sidebarPageletsController];
        [sidebarPageletsController addObjects:pagelets];
    }
    else
    {
        NSBeep();
    }
}

- (IBAction)placeBlockLevel:(id)sender;    // tells all selected graphics to become placed as block
{
    [(SVWebEditorItem *)[self focusedText] tryToPerform:_cmd with:sender];
}

- (IBAction)placeBlockLevelIfNeeded:(NSButton *)sender; // calls -placeBlockLevel if sender's state is on
{
    if ([sender state] == NSOnState) [self placeBlockLevel:sender];
}

@end

