//
//  SVWebEditorViewController.m
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorViewController.h"

#import "SVApplicationController.h"
#import "SVArticle.h"
#import "SVAttributedHTML.h"
#import "SVPlugInGraphic.h"
#import "SVLogoImage.h"
#import "KTMaster.h"
#import "KTPage.h"
#import "SVGraphicDOMController.h"
#import "SVGraphicFactory.h"
#import "SVRichTextDOMController.h"
#import "SVLink.h"
#import "SVLinkManager.h"
#import "SVMediaRecord.h"
#import "KTSite.h"
#import "SVSelectionBorder.h"
#import "SVSidebar.h"
#import "SVSidebarDOMController.h"
#import "SVSidebarPageletsController.h"
#import "SVTextAttachment.h"
#import "SVWebContentAreaController.h"
#import "SVWebContentObjectsController.h"
#import "SVWebEditorHTMLContext.h"
#import "KTDocument.h"

#import "NSArray+Karelia.h"
#import "NSResponder+Karelia.h"
#import "NSURL+Karelia.h"
#import "NSWorkspace+Karelia.h"
#import "DOMNode+Karelia.h"
#import "DOMRange+Karelia.h"

#import "KSCollectionController.h"
#import "KSPlugInWrapper.h"
#import "KSSilencingConfirmSheet.h"

#import <BWToolkitFramework/BWToolkitFramework.h>


NSString *sSVWebEditorViewControllerWillUpdateNotification = @"SVWebEditorViewControllerWillUpdateNotification";


@interface SVWebEditorViewController ()

@property(nonatomic, readwrite) BOOL viewIsReadyToAppear;

@property(nonatomic, readwrite, getter=isUpdating) BOOL updating;
- (void)removeAllDependencies;

@property(nonatomic, retain, readwrite) SVWebEditorHTMLContext *HTMLContext;

@property(nonatomic, retain, readonly) SVWebContentObjectsController *primitiveSelectedObjectsController;

@end


#pragma mark -


@implementation SVWebEditorViewController

#pragma mark Init & Dealloc

- (id)init
{
    self = [super init];
    
    _graphicsController = [[SVWebContentObjectsController alloc] init];
    [_graphicsController setAvoidsEmptySelection:NO];
    [_graphicsController setPreservesSelection:NO];    // we'll take care of that
    [_graphicsController setSelectsInsertedObjects:NO];
    [_graphicsController setObjectClass:[NSObject class]];
        
    return self;
}
    
- (void)dealloc
{
    [self removeAllDependencies];
    OBASSERT(!_pageDependencies);
    
    [[[self webEditor] undoManager] removeAllActionsWithTarget:self];
    
    [self setWebEditor:nil];   // needed to tear down data source
    [self setDelegate:nil];
    
    [_page release];
    [_context release];
    [_graphicsController release];
    
    [super dealloc];
}

#pragma mark Views

- (void)loadView
{
    WEKWebEditorView *editor = [[WEKWebEditorView alloc] init];
    
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
- (void)setWebEditor:(WEKWebEditorView *)editor
{
    [[self webEditor] setDelegate:nil];
    [[self webEditor] setDataSource:nil];
    [[self webEditor] setDraggingDestinationDelegate:nil];
    
    [editor retain];
    [_webEditorView release];
    _webEditorView = editor;
    
    [editor setDelegate:self];
    [editor setDataSource:self];
    [editor setDraggingDestinationDelegate:self];
    [editor setAllowsUndo:NO];  // will be managing this entirely ourselves
}

#pragma mark Presentation

@synthesize viewIsReadyToAppear = _readyToAppear;
- (void)setViewIsReadyToAppear:(BOOL)ready;
{
    _readyToAppear = ready;
    
    if ([_contentAreaController selectedViewControllerWhenReady] == self)
    {
        if (ready)
        {
            [_contentAreaController setSelectedViewController:self];
        }
        else
        {
            [_contentAreaController presentLoadingViewController];
        }
    }
}

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
    
    if (![self isUpdating]) [self setPage:nil];
    
    // Once we move offsreen, we're no longer suitable to be shown
    [self setViewIsReadyToAppear:NO];
}

#pragma mark Loading

/*  Loading is to Updating as Drawing is to Displaying (in NSView)
 */

- (void)loadPageHTMLIntoWebEditor
{
    // Tear down old dependencies and DOM controllers.
    [self removeAllDependencies];
    [[[self webEditor] rootItem] setChildWebEditorItems:nil];
    
    
    // Prepare the environment for generating HTML
    KTPage *page = [self page];
    [_graphicsController setPage:page]; // do NOT set the controller's MOC. Unless you set both MOC
                                                        // and entity name, saving will raise an exception. (crazy I know!)
    
    
    // Construct HTML Context
    NSMutableString *pageHTML = [[NSMutableString alloc] init];
	SVWebEditorHTMLContext *context = [[SVWebEditorHTMLContext alloc] initWithOutputWriter:pageHTML];
    
    [context setPage:page];
    [context setLiveDataFeeds:[[NSUserDefaults standardUserDefaults] boolForKey:kSVLiveDataFeedsKey]];
    [context setSidebarPageletsController:[_graphicsController sidebarPageletsController]];
    
    
    // Go for it. You write that HTML girl!
	[page writeHTML:context];
    [context flush];
    
    
    //  Start loading. Some parts of WebKit need to be attached to a window to work properly, so we need to provide one while it's loading in the
    //  background. It will be removed again after has finished since the webview will be properly part of the view hierarchy.
    
    [[self webView] setHostWindow:[[self view] window]];   // TODO: Our view may be outside the hierarchy too; it woud be better to figure out who our window controller is and use that.
    [self setHTMLContext:context];
    
    
    // Record that the webview is being loaded with content. Otherwise, the policy delegate will refuse requests. Also record location
    [self setUpdating:YES];
    _visibleRect = [[[self webEditor] documentView] visibleRect];
    
    
	// Figure out the URL to use. 
	NSURL *pageURL = [context baseURL];
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

- (void)webEditorViewDidFinishLoading:(WEKWebEditorView *)sender;
{
    WEKWebEditorView *webEditor = [self webEditor];
    DOMDocument *domDoc = [webEditor HTMLDocument];
    OBASSERT(domDoc);
    
    
    // Context holds the controllers. We need to send them over to the Web Editor.
    // Doing so will populate .graphicsController, so need to clear out its content & remember the selection first
    
    NSArray *selection = [[self graphicsController] selectedObjects];
    [[self graphicsController] setContent:nil];
    
    SVWebEditorHTMLContext *context = [self HTMLContext];
    NSArray *controllers = [context DOMControllers];
        
    for (WEKWebEditorItem *anItem in controllers)
    {
        [[webEditor rootItem] addChildWebEditorItem:anItem];
    }
    
    [[self graphicsController] setSelectedObjects:selection];    // restore selection
    
    
    // Restore scroll point
    [[self webEditor] scrollToPoint:_visibleRect.origin];
    
    
    // Mark as loaded
    [self setUpdating:NO];
    [self setViewIsReadyToAppear:YES];
    
    
    // Did Update
    [self didUpdate];
    
    // Can now ditch context contents
    [context close];
}

#pragma mark Updating

- (void)update;
{
	[self willUpdate];
    
	[self loadPageHTMLIntoWebEditor];
	
    // Clearly the webview is no longer in need of refreshing
    _willUpdate = NO;
	_needsUpdate = NO;
}

@synthesize updating = _isUpdating;

- (void)scheduleUpdate
{
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
    //[self removeAllDependencies];   // no point observing now we're marked for update
}

- (void)removeAllDependencies;
{
    for (KSObjectKeyPathPair *aDependency in _pageDependencies)
    {
        [[aDependency object] removeObserver:self
                                  forKeyPath:[aDependency keyPath]];
    }
    
    [_pageDependencies release]; _pageDependencies = nil;
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
        [[[self webEditor] rootItem] updateIfNeeded];
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
    WEKWebEditorView *webEditor = [self webEditor];
    
    
    // Match selection to controller
    NSArray *selectedObjects = [[self graphicsController] selectedObjects];
    NSMutableArray *newSelection = [[NSMutableArray alloc] initWithCapacity:[selectedObjects count]];
    
    for (id anObject in selectedObjects)
    {
        id newItem = [[[self webEditor] rootItem] hitTestRepresentedObject:anObject];
        if ([newItem isSelectable]) [newSelection addObject:newItem];
    }
    
    [[self webEditor] selectItems:newSelection byExtendingSelection:NO];   // this will feed back to us and the controller in notification
    [newSelection release];
    
    
    // Restore selection
    if (_selectionToRestore)
    {
        [webEditor setSelectedTextRange:_selectionToRestore affinity:NSSelectionAffinityDownstream];
        [_selectionToRestore release]; _selectionToRestore = nil;
    }
    
    // Fallback to end of article if needs be. #75712
    if (![webEditor selectedItem] && ![webEditor selectedDOMRange])
    {
        if ([webEditor ks_followsResponder:[[[self view] window] firstResponder]])
        {
            DOMRange *range = [self webEditor:webEditor fallbackDOMRangeForNoSelection:nil];
            [webEditor setSelectedDOMRange:range affinity:0];
        }
    }
}

#pragma mark Content

@synthesize primitiveSelectedObjectsController = _graphicsController;
- (id <KSCollectionController>)graphicsController
{
    return [self primitiveSelectedObjectsController];
}

@synthesize firstResponderItem = _firstResponderItem;

@synthesize HTMLContext = _context;
- (void)setHTMLContext:(SVWebEditorHTMLContext *)context;
{
    if (context != [self HTMLContext])
    {
        [[self HTMLContext] setWebEditorViewController:nil];
        [_context release]; _context = [context retain];
        [context setWebEditorViewController:self];
    }
}

@synthesize page = _page;
- (void)setPage:(KTPage *)page
{
    if (page != _page)
    {
        [_page release]; _page = [page retain];
    
        [self update];
    }
}

- (void)registerWebEditorItem:(WEKWebEditorItem *)item;  // recurses through, registering descendants too
{
    // Ensure element is loaded
    DOMDocument *domDoc = [[self webEditor] HTMLDocument];
    if (![item isHTMLElementCreated]) [item loadHTMLElementFromDocument:domDoc];
    OBASSERT([item HTMLElement]);
    
    
    //  Populate controller with content. For now, this is simply all the represented objects of all the DOM controllers
    id anObject = [item representedObject];
    if (anObject && //  second bit of this if statement: images are owned by 2 DOM controllers, DON'T insert twice!
        ![[_graphicsController arrangedObjects] containsObjectIdenticalTo:anObject])
    {
        [[self graphicsController] addObject:anObject];
    }
    
    
    // Register descendants
    for (WEKWebEditorItem *anItem in [item childWebEditorItems])
    {
        [self registerWebEditorItem:anItem];
    }
}

#pragma mark Text Areas

- (SVTextDOMController *)textAreaForDOMNode:(DOMNode *)node;
{
    WEKWebEditorItem *controller = [[[self webEditor] rootItem] hitTestDOMNode:node];
    SVTextDOMController *result = [controller textDOMController];
    return result;
}

- (SVTextDOMController *)textAreaForDOMRange:(DOMRange *)range;
{
    // One day there might be better logic to apply, but for now, testing the start of the range is enough
    return [self textAreaForDOMNode:[range startContainer]];
}

#pragma mark Element Insertion

- (void)_insertPageletInSidebar:(SVGraphic *)pagelet;
{
    // Place at end of the sidebar
    [[_graphicsController sidebarPageletsController] addObject:pagelet];
    
    // Add to main controller too
    NSArrayController *controller = [self graphicsController];
    
    BOOL selectInserted = [controller selectsInsertedObjects];
    [controller setSelectsInsertedObjects:YES];
    [controller addObject:pagelet];
    [controller setSelectsInsertedObjects:selectInserted];
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
    if (!page) return NSBeep(); // pretty rare. #75495
    
    
    SVGraphic *pagelet = [SVGraphicFactory graphicWithActionSender:sender
                                      insertIntoManagedObjectContext:[page managedObjectContext]];
    
    
    // Insert it
    [pagelet willInsertIntoPage:page];
    [self _insertPageletInSidebar:pagelet];
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
                                            entityName:@"GraphicMedia"
                        insertIntoManagedObjectContext:context
                                                 error:NULL];
    
    if (media)
    {
        SVImage *image = [SVImage insertNewImageWithMedia:media];
        [image willInsertIntoPage:[self page]];
        [self _insertPageletInSidebar:image];
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
    for (id anObject in [[self graphicsController] selectedObjects])
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

- (IBAction)paste:(id)sender;
{
    SVSidebarPageletsController *sidebarPageletsController =
    [_graphicsController sidebarPageletsController];
    
    NSUInteger index = [sidebarPageletsController selectionIndex];
    if (index >= NSNotFound) index = 0;
    
    [sidebarPageletsController insertPageletsFromPasteboard:[NSPasteboard generalPasteboard]
                                      atArrangedObjectIndex:index];
}


#pragma mark Graphic Placement

- (BOOL)doPlacementCommandBySelector:(SEL)action;
{
    // Whenever there's some kind of text selection, the responsible controller must take it. If there's no controller, cannot perform
    NSResponder *textController = [self firstResponderItem];
    if (textController)
    {
        [textController doCommandBySelector:action];
    }
    else if ([[self webEditor] selectedDOMRange])
    {
        NSBeep();
    }
    else
    {
        return NO;
    }
    
    return YES;
}

- (void)placeInline:(id)sender;
{
    // Whenever there's some kind of text selection, the responsible controller must take it. If there's no controller, cannot perform
    [self doPlacementCommandBySelector:_cmd];
    
    // TODO: Handle going from sidebar to inline
}

- (IBAction)placeAsBlock:(id)sender;    // tells all selected graphics to become placed as block
{
    // Whenever there's some kind of text selection, the responsible controller must take it. If there's no controller, cannot perform
    [self doPlacementCommandBySelector:_cmd];
    
    // TODO: Handle going from sidebar to block
}

- (IBAction)placeBlockLevelIfNeeded:(NSButton *)sender; // calls -placeBlockLevel if sender's state is on
{
    if ([sender state] == NSOnState)
    {
        [self doPlacementCommandBySelector:@selector(placeBlockLevel:)];
    }
}

- (IBAction)placeAsCallout:(id)sender;
{
    // Whenever there's some kind of text selection, the responsible controller must take it. If there's no controller, cannot perform
    [self doPlacementCommandBySelector:_cmd];
    
    // TODO: Handle going from sidebar to callout
}

- (IBAction)placeInSidebar:(id)sender;
{
    // Whenever there's some kind of text selection, the responsible controller must take it. If there's no controller, cannot perform
    [self doPlacementCommandBySelector:_cmd];
    
    // Otherwise assume selection is already in sidebar so nothing needs doing
}

#pragma mark Action Forwarding

- (void)makeTextLarger:(id)sender;
{
    [[self webView] makeTextLarger:sender];
}

- (void)makeTextSmaller:(id)sender;
{
    [[self webView] makeTextSmaller:sender];
}

- (void)makeTextStandardSize:(id)sender;
{
    [[self webView] makeTextStandardSize:sender];
}

- (BOOL)tryToMakeSelectionPerformAction:(SEL)action with:(id)anObject;
{
    DOMRange *selection = [[self webEditor] selectedDOMRange];
    if (selection)
    {
        SVTextDOMController *text = [self textAreaForDOMRange:selection];
        return [text tryToPerform:action with:anObject];
    }
    return NO;
}

#pragma mark Undo

- (void)undo_setSelectedTextRange:(SVWebEditorTextRange *)range;
{
    // Ignore if not already marked for update, since that could potentially reset the selection in the distant future, which is very odd for users. Ideally, this situation won't arrive
    if (![self needsUpdate]) return;
    
    
    [_selectionToRestore release]; _selectionToRestore = [range copy];
    
    // Push opposite onto undo stack
    WEKWebEditorView *webEditor = [self webEditor];
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
        
        
        if (action == @selector(makeTextLarger:))
        {
            result = [[self webView] canMakeTextLarger];
        }
        else if (action == @selector(makeTextSmaller:))
        {
            result = [[self webView] canMakeTextSmaller];
        }
        else if (action == @selector(makeTextStandardSize:))
        {
            result = [[self webView] canMakeTextStandardSize];
        }
        
        else if (action == @selector(insertSiteTitle:))
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
            for (id <NSObject> anObject in [[self graphicsController] selectedObjects])
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

- (BOOL)viewShouldAppear:(BOOL)animated webContentAreaController:(SVWebContentAreaController *)controller
{
    _contentAreaController = controller;    // weak ref
    
    [self setPage:[[controller selectedPage] pageRepresentation]];
    return [self viewIsReadyToAppear];
}

#pragma mark -

#pragma mark WebEditorViewDataSource

- (WEKWebEditorItem <SVWebEditorText> *)webEditor:(WEKWebEditorView *)sender
                             textBlockForDOMRange:(DOMRange *)range;
{
    return [self textAreaForDOMRange:range];
}

- (BOOL)webEditor:(WEKWebEditorView *)sender deleteItems:(NSArray *)items;
{
    NSArray *objects = [items valueForKey:@"representedObject"];
    if ([objects isEqualToArray:[[self graphicsController] selectedObjects]])
    {
        [[self graphicsController] remove:self];
    }
    else
    {
        [[self graphicsController] removeObjects:objects];
    }
    
    return YES;
}

- (BOOL)webEditor:(WEKWebEditorView *)sender addSelectionToPasteboard:(NSPasteboard *)pasteboard;
{
    BOOL result = NO;
    SVTextDOMController *textController = [[self firstResponderItem] textDOMController];
    
    
    if (textController)
    {
        [textController addSelectionTypesToPasteboard:pasteboard];
        return YES;
    }
    else
    {
        // Want serialized pagelets on pboard
        SVGraphic *graphic = [[sender selectedItem] representedObject];
        if ([graphic isKindOfClass:[SVGraphic class]])
        {
            result = YES;
            
            [pasteboard addTypes:[NSArray arrayWithObject:kSVGraphicPboardType] owner:self];
            [graphic writeToPasteboard:pasteboard];
        }
        
        // Place HTML on pasteboard
        //[pasteboard setString:html forType:NSHTMLPboardType];
        //[html release];
        //[pasteboard addTypes:[NSArray arrayWithObject:NSHTMLPboardType] owner:self];
    }
    
    
    
    return result;
}

// Same as WebUIDelegate method, except it only gets called if .draggingDestinationDelegate rejected the drag
- (NSUInteger)webEditor:(WEKWebEditorView *)sender dragDestinationActionMaskForDraggingInfo:(id <NSDraggingInfo>)draggingInfo;
{
    NSUInteger result = WebDragDestinationActionDHTML;
    
    NSArray *types = [[draggingInfo draggingPasteboard] types];
    if (![types containsObject:kSVGraphicPboardType] &&
        ![types containsObject:@"com.karelia.html+graphics"])
    {
        result = result | WebDragDestinationActionEdit;
    }
    
    return result;
}

#pragma mark SVWebEditorViewDelegate

- (void)webEditorViewDidFirstLayout:(WEKWebEditorView *)sender;
{
    OBPRECONDITION(sender == [self webEditor]);
    [self webViewDidFirstLayout];
}

           - (BOOL)webEditor:(WEKWebEditorView *)sender
shouldChangeSelectedDOMRange:(DOMRange *)currentRange
                  toDOMRange:(DOMRange *)proposedRange
                    affinity:(NSSelectionAffinity)selectionAffinity
                       items:(NSArray *)proposedSelectedItems
              stillSelecting:(BOOL)stillSelecting;
{
    //  Update our content controller's selected objects to reflect the new selection in the Web Editor View
    
    OBPRECONDITION(sender == [self webEditor]);
    
    // HACK: Ignore these messages while loading as we'll sort out selection once the load is done
    BOOL result = YES;
    if (![self isUpdating])
    {
        // If there is a text selection, it may encompass more than a single object. If so, ignore selected items
        if (proposedRange)
        {
            if ([proposedSelectedItems count] == 1)
            {
                WEKWebEditorItem *item = [proposedSelectedItems objectAtIndex:0];
                if (![proposedRange ks_selectsNode:[item HTMLElement]]) proposedSelectedItems = nil;
            }
            else
            {
                proposedSelectedItems = nil;
            }
        }
        
                                                            
        // Match the controller's selection to the view
        NSArray *objects = [proposedSelectedItems valueForKey:@"representedObject"];
        result = [[self graphicsController] setSelectedObjects:objects];
    }
    
    return result;
}

- (void)webEditorDidChangeSelection:(NSNotification *)notification;
{
    WEKWebEditorView *webEditor = [notification object];
    OBPRECONDITION(webEditor == [self webEditor]);
    
    
    // Set our first responder item to match
    id controller = [webEditor focusedText];
    if (!controller)
    {
        NSSet *selection = [[NSSet alloc] initWithArray:[webEditor selectedItems]];
        NSSet *containerControllers = [selection valueForKey:@"textDOMController"];
        
        if ([containerControllers count] == 0)  // fallback to sidebar DOM controller
        {
            containerControllers = [selection valueForKey:@"sidebarDOMController"];
        }
        
        if ([containerControllers count] == 1)
        {
            controller = [containerControllers anyObject];
        }
    }
    [self setFirstResponderItem:controller];
    
    
    // Do something?? link related
    if (![[self webEditor] selectedDOMRange])
    {
        SVLink *link = [[self graphicsController] valueForKeyPath:@"selection.link"];
        
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

- (DOMRange *)webEditor:(WEKWebEditorView *)sender fallbackDOMRangeForNoSelection:(NSEvent *)selectionEvent;
{
    SVRichText *article = [[self page] article];
    SVTextDOMController *item = (id)[[[self webEditor] rootItem] hitTestRepresentedObject:article];
    DOMNode *articleNode = [item textHTMLElement];
    
    DOMRange *result = [[articleNode ownerDocument] createRange];
    
    NSPoint location = [[articleNode documentView] convertPointFromBase:[selectionEvent locationInWindow]];
    if (selectionEvent && location.y < NSMidY([articleNode boundingBox]))
    {
        [result setStartBefore:[articleNode firstChild]];
    }
    else
    {
        [result setStartAfter:[articleNode lastChild]];
    }
    
    return result;
}

- (BOOL)webEditor:(WEKWebEditorView *)sender createLink:(SVLinkManager *)actionSender;
{
    if (![sender selectedDOMRange])
    {
        SVLink *link = [actionSender selectedLink];
        [[self graphicsController] setValue:link forKeyPath:@"selection.link"];
        return YES;
    }
    
    return NO;
}

- (void)webEditor:(WEKWebEditorView *)sender didReceiveTitle:(NSString *)title;
{
    [self setTitle:title];
}

- (NSURLRequest *)webEditor:(WEKWebEditorView *)sender
            willSendRequest:(NSURLRequest *)request
           redirectResponse:(NSURLResponse *)redirectResponse
             fromDataSource:(WebDataSource *)dataSource;
{
    // Force the WebView to dump its cached resources from the WebDataSource so that any change to main.css gets picked up
    /*
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
    }    */
    
    
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

- (void)webEditor:(WEKWebEditorView *)sender handleNavigationAction:(NSDictionary *)actionInfo request:(NSURLRequest *)request;
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
    WEKWebEditorView *webEditor = [self webEditor];
    NSUndoManager *undoManager = [webEditor undoManager];
    
    // There's no point recording the action if registration is disabled. Especially since grabbing the selection is a relatively expensive op
    if ([undoManager isUndoRegistrationEnabled])
    {
        [[undoManager prepareWithInvocationTarget:self] 
         undo_setSelectedTextRange:[webEditor selectedTextRange]];
    }
}

- (BOOL)webEditor:(WEKWebEditorView *)sender doCommandBySelector:(SEL)action;
{
    // Take over pasting if the Web Editor can't support it
    if (action == @selector(paste:) && ![sender validateAction:action])
    {
        [self paste:nil];
        return YES;
    }
    else if (action == @selector(moveUp:) || action == @selector(moveDown:))
    {
        for (WEKWebEditorItem *anItem in [sender selectedItems])
        {
            if ([anItem sidebarDOMController])
            {
                [[_graphicsController sidebarPageletsController] performSelector:action
                                                                      withObject:nil];
                break;
            }
        }        
    }
    else if (action == @selector(reload:))
    {
        [self doCommandBySelector:action];
    }
    
    
    return NO;
}

- (void)webEditor:(WEKWebEditorView *)sender didAddItem:(WEKWebEditorItem *)item;
{
    OBPRECONDITION(sender == [self webEditor]);
    [self registerWebEditorItem:item];
}

#pragma mark NSDraggingDestination

- (NSObject *)destinationForDraggingInfo:(id <NSDraggingInfo>)dragInfo;
{
    WEKWebEditorView *webEditor = [self webEditor];
    
    NSDictionary *element = [[webEditor webView] elementAtPoint:
                             [webEditor convertPointFromBase:[dragInfo draggingLocation]]];
    
    DOMNode *node = [element objectForKey:WebElementDOMNodeKey];
    
    id result = [[webEditor rootItem] hitTestDOMNode:node draggingInfo:dragInfo];
    
    if (!result)
    {
        // Don't allow drops of pagelets inside non-page body text.
        if ([dragInfo draggingSource] == webEditor && [[webEditor draggedItems] count])
        {
            if (![[[[[self textAreaForDOMNode:node] representedObject] entity] name]
                  isEqualToString:@"Article"])
            {
                result = nil;
            }
        }
    }
    
    
    return result;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
{
    _draggingDestination = [self destinationForDraggingInfo:sender];
    return [_draggingDestination draggingEntered:sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender;
{
    NSObject *destination = [self destinationForDraggingInfo:sender];
    
    // Switching to a new drag target, so tell the old one drag exited
    if (destination == _draggingDestination)
    {
        return [_draggingDestination draggingUpdated:sender];
    }
    else
    {
        if ([_draggingDestination respondsToSelector:@selector(draggingExited:)])
        {
            [_draggingDestination draggingExited:sender];
        }
        
        _draggingDestination = destination;
        return [_draggingDestination draggingEntered:sender];
    }
}

- (void)draggingExited:(id <NSDraggingInfo>)sender;
{
    if ([_draggingDestination respondsToSelector:_cmd]) [_draggingDestination draggingExited:sender];
    _draggingDestination = nil;
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;
{
    BOOL result = YES;
    
    if ([_draggingDestination respondsToSelector:_cmd])
    {
        result = [_draggingDestination prepareForDragOperation:sender];
    }
    
    return result;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
{
    BOOL result = [_draggingDestination performDragOperation:sender];
    return result;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;
{
    if ([_draggingDestination respondsToSelector:_cmd])
    {
        [_draggingDestination concludeDragOperation:sender];
    }
}

- (void)draggingEnded:(id <NSDraggingInfo>)sender;
{
    if ([_draggingDestination respondsToSelector:_cmd])
    {
        [_draggingDestination draggingEnded:sender];
    }
    _draggingDestination = nil;
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

