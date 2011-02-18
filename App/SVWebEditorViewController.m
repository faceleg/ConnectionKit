//
//  SVWebEditorViewController.m
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVWebEditorViewController.h"

#import "SVApplicationController.h"
#import "SVArticle.h"
#import "SVAttributedHTML.h"
#import "SVContentDOMController.h"
#import "KTDocument.h"
#import "KTDocWindowController.h"
#import "SVImage.h"
#import "SVLogoImage.h"
#import "KTMaster.h"
#import "KTPage.h"
#import "SVGraphicDOMController.h"
#import "SVGraphicFactory.h"
#import "KTHTMLEditorController.h"
#import "SVLinkManager.h"
#import "SVMedia.h"
#import "SVPlugInGraphic.h"
#import "KTSite.h"
#import "KSSelectionBorder.h"
#import "SVRawHTMLGraphic.h"
#import "SVRichTextDOMController.h"
#import "SVSidebar.h"
#import "SVSidebarDOMController.h"
#import "SVSidebarPageletsController.h"
#import "SVTextAttachment.h"
#import "SVWebContentAreaController.h"
#import "SVWebContentObjectsController.h"
#import "SVWebEditorHTMLContext.h"
#import "SVWebEditorTextRange.h"

#import "NSArray+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSResponder+Karelia.h"
#import "KSURLUtilities.h"
#import "NSWorkspace+Karelia.h"
#import "DOMNode+Karelia.h"
#import "DOMRange+Karelia.h"

#import "KSCollectionController.h"
#import "KSPlugInWrapper.h"
#import "KSSilencingConfirmSheet.h"

#import <BWToolkitFramework/BWToolkitFramework.h>


NSString *sSVWebEditorViewControllerWillUpdateNotification = @"SVWebEditorViewControllerWillUpdateNotification";

static NSString *sSelectedLinkObservationContext = @"SVWebEditorSelectedLinkObservation";


@interface DOMNode (KSHTMLWriter)
- (BOOL)ks_isDescendantOfDOMNode:(DOMNode *)possibleAncestor;
@end


#pragma mark -


@interface SVWebEditorViewController ()

@property(nonatomic, readwrite) BOOL viewIsReadyToAppear;

- (void)willUpdate;
- (void)didUpdate;  // if an asynchronous update, called after the update finishes

@property(nonatomic, retain, readwrite) SVContentDOMController *contentDOMController;
@property(nonatomic, retain, readwrite) SVWebEditorHTMLContext *HTMLContext;

@property(nonatomic, retain, readonly) SVWebContentObjectsController *primitiveSelectedObjectsController;

- (void)setSelectedTextRange:(SVWebEditorTextRange *)textRange affinity:(NSSelectionAffinity)affinity;
- (void)selectObjects:(NSArray *)objects inWebEditor:(WEKWebEditorView *)webEditor;

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
    
    [_graphicsController addObserver:self forKeyPath:@"selection.link" options:0 context:sSelectedLinkObservationContext];
        
    return self;
}
    
- (void)dealloc
{
    [_graphicsController removeObserver:self forKeyPath:@"selection.link"];
    
    [[[self webEditor] undoManager] removeAllActionsWithTarget:self];
    
    [self setContentDOMController:nil];
    [self setWebEditor:nil];   // needed to tear down data source
    [self setDelegate:nil];
    
    [_firstResponderItem release];
    [_context release];
    [_graphicsController release];
    [_loadedPage release];
    
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
    
    // Once we're not the interesting view, stop tracking for updates. This is particular important during undo/redo where it would otherwise be possible to continue tracking a deleted object
    if ([_contentAreaController selectedViewControllerWhenReady] != self)
    {
        [self loadPage:nil];
    }
    
    // Once we move offscreen, we're no longer suitable to be shown
    [self setViewIsReadyToAppear:NO];
	
	// Close out the HTML editor
	[self.parentViewController.view.window.windowController setHTMLEditorController:nil];
}

#pragma mark Loading

/*  Loading is to Updating as Drawing is to Displaying (in NSView)
 */

- (void)loadPage:(KTPage *)page;
{
    // Mark as updating. Reset counter first since loading page wipes away any in-progress updates
    _updatesCount = 0;
    [self willUpdate];
    
    WEKWebEditorView *webEditor = [self webEditor];
    
    
    // Tear down old dependencies and DOM controllers.
    [webEditor setContentItem:nil];
    
    
    // Prepare the environment for generating HTML
    [_graphicsController setPage:page]; // do NOT set the controller's MOC. Unless you set both MOC
                                                        // and entity name, saving will raise an exception. (crazy I know!)
    
    
    // Construct HTML Context
	SVWebEditorHTMLContext *context = [[SVWebEditorHTMLContext alloc] init];
    
    [context setLiveDataFeeds:[[NSUserDefaults standardUserDefaults] boolForKey:kSVLiveDataFeedsKey]];
    [context setSidebarPageletsController:[_graphicsController sidebarPageletsController]];
    
    
    // Go for it. You write that HTML girl!
	if (page) [context writeDocumentWithPage:page];
    [context flush];
        
    
    //  Start loading. Some parts of WebKit need to be attached to a window to work properly, so we need to provide one while it's loading in the
    //  background. It will be removed again after has finished since the webview will be properly part of the view hierarchy.
    
    [self setHTMLContext:context];  // sets .contentDOMController as a side-effect
    
    
    // Record location
    _visibleRect = [[webEditor documentView] visibleRect];
    
    
	// Figure out the URL to use. 
	NSURL *pageURL = [context baseURL];
    if (![pageURL scheme] ||        // case 44071: WebKit will not load the HTML or offer delegate
        ![pageURL host] ||          // info if the scheme is something crazy like fttp:
        !([[pageURL scheme] isEqualToString:@"http"] || [[pageURL scheme] isEqualToString:@"https"]))
    {
        pageURL = nil;
    }
    
    
    // Load the HTML into the webview
    NSString *pageHTML = [[context outputStringWriter] string];
    [webEditor loadHTMLString:pageHTML baseURL:pageURL];
    
    
    // Tidy up. Web Editor HTML Contexts create a retain cycle until -close is called. Yes, I should fix this at some point, but it's part of the design for now. We call -close once the webview has loaded, but sometimes that point is never reached! As far as I can tell it's not a problem to close the context after starting a load. Researched into this prompted by #
    [context close];
    [context release];
}

- (KTPage *)loadedPage; // the last page to successfully load into Web Editor
{
    return _loadedPage;
}

- (void)webEditorViewDidFinishLoading:(WEKWebEditorView *)sender;
{
    WEKWebEditorView *webEditor = [self webEditor];
    DOMDocument *domDoc = [webEditor HTMLDocument];
	#pragma unused (domDoc)
    OBASSERT(domDoc);
    
    
    // Context holds the controllers. We need to send them over to the Web Editor.
    // Doing so will populate .graphicsController, so need to clear out its content & remember the selection first
    
    NSArray *selection = [[self graphicsController] selectedObjects];
    [[self graphicsController] setContent:nil];
    
    SVWebEditorHTMLContext *context = [self HTMLContext];
    [_loadedPage release]; _loadedPage = [[context page] retain];
    [webEditor setContentItem:[self contentDOMController]];
    
    [[self graphicsController] setSelectedObjects:selection];    // restore selection
    
    
    // Restore scroll point
    [[self webEditor] scrollToPoint:_visibleRect.origin];
    
    
    // Did Update
    [self didUpdate];
    

    // Mark as loaded
    [self setViewIsReadyToAppear:YES];
    
    
    // Give focus to article? This has to wait until we're onscreen
    if ([self articleShouldBecomeFocusedAfterNextLoad])
    {
        if ([[[self view] window] makeFirstResponder:[self webEditor]])
        {
            SVRichTextDOMController *articleController = (id)[self articleDOMController];
            DOMDocument *document = [[articleController HTMLElement] ownerDocument];
            
            DOMRange *range = [document createRange];
            [range setStart:[articleController textHTMLElement] offset:0];
            [[self webEditor] setSelectedDOMRange:range affinity:0];
        }
        
        [self setArticleShouldBecomeFocusedAfterNextLoad:NO];
    }
    
    
    // Can now ditch context contents
    [context close];
}

@synthesize articleShouldBecomeFocusedAfterNextLoad = _articleShouldBecomeFocusedAfterNextLoad;

#pragma mark Updating

- (void)update;
{
    _reload = NO;
	
    // Clearly the webview is no longer in need of refreshing
    // Used to mark this *after* -loadPage: but it's possible that a change could happen while loading, mark us for update, but then be wiped out once -loadPage: returns
    _willUpdate = NO;
	_needsUpdate = NO;
    
    [self loadPage:[[self HTMLContext] page]];
}

- (BOOL)isUpdating; { return _updatesCount; }

- (void)willUpdate;
{
    if (![self isUpdating]) 
    {
        [[NSNotificationCenter defaultCenter]
         postNotificationName:sSVWebEditorViewControllerWillUpdateNotification
         object:self];
    
		float delay = 1.0f;		// was 0.1f; Dan liked longer delay
        // If the update takes too long, switch over to placeholder
        [self performSelector:@selector(updateDidTimeout) withObject:nil afterDelay:delay];
    }
    
    
    // Record that the webview is being loaded with content. Otherwise, the policy delegate will refuse requests. Also record location
    _updatesCount++;
}

- (void)didUpdate;
{
    // Lower the update count, checking if we're already at 0 to avoid wraparound (could've made a mistake)
    if ([self isUpdating])
    {
        _updatesCount--;
    
        // Nothing to do if still going
        if ([self isUpdating]) return;
    }
    
    
    // Need no further action during live resize. #83927
    WEKWebEditorView *webEditor = [self webEditor];
    if ([webEditor inLiveGraphicResize]) return;
    
    
    // Cancel the timer
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(updateDidTimeout)
                                               object:nil];
    
    
    // Make sure we're in view if desired
    if ([_contentAreaController selectedViewControllerWhenReady] == self)
    {
        [_contentAreaController setSelectedViewController:self];
    }
    
    
    // Match selection to controller
    NSArray *selectedObjects = [[self graphicsController] selectedObjects];
    NSArray *currentSelectedObjects = [[webEditor selectedItems] valueForKey:@"representedObject"];
    
    if (![selectedObjects isEqualToArray:currentSelectedObjects])
    {
        [self selectObjects:selectedObjects inWebEditor:webEditor];
    }
    
    
    // Restore selection…
    if (_selectionToRestore)
    {
        // …but only if WebView's First Responder
        if ([webEditor ks_followsResponder:[[webEditor window] firstResponder]])
        {
            [self setSelectedTextRange:_selectionToRestore affinity:NSSelectionAffinityDownstream];
        }
        
        [_selectionToRestore release]; _selectionToRestore = nil;
    }
    
    
    // Scroll selection into view
    if ([webEditor selectedItem])
    {
        [webEditor scrollItemToVisible:[webEditor selectedItem]];
    }
}

- (void)updateDidTimeout
{
    if ([self parentViewController] == _contentAreaController &&
        [_contentAreaController selectedViewControllerWhenReady] == self)
    {
        [_contentAreaController presentLoadingViewController];
    }
}

#pragma mark Update Scheduling

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
                                              modes:NSARRAY(NSDefaultRunLoopMode, NSEventTrackingRunLoopMode)];
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

- (void)updateIfNeeded
{
    if (!_willUpdate) return;   // don't you waste my time sucker!
    	
    if ([self needsUpdate])
    {
        [self update];
    }
    else
    {
        // Bracket -updateIfNeeded so final -didUpdate call happens at least after all controllers have been given a chance to update. #95683
        [self willUpdate];
        @try
        {
            [[[self webEditor] contentItem] updateIfNeeded];    // will call -didUpdate if anything did
        }
        @finally
        {
            [self didUpdate];
        }
        
        _willUpdate = NO;
    }
}

- (IBAction)reload:(id)sender
{
    _reload = YES;
    [self loadPage:[[self HTMLContext] page]];
}

#pragma mark Content

@synthesize primitiveSelectedObjectsController = _graphicsController;
- (id <KSCollectionController>)graphicsController
{
    return [self primitiveSelectedObjectsController];
}

@synthesize firstResponderItem = _firstResponderItem;

@synthesize contentDOMController = _contentItem;
- (void)setContentDOMController:(SVContentDOMController *)controller;
{
    [[self contentDOMController] setWebEditorViewController:nil];
    
    [controller retain];
    [_contentItem release]; _contentItem = controller;
    
    [controller setWebEditorViewController:self];
}

@synthesize HTMLContext = _context;
- (void)setHTMLContext:(SVWebEditorHTMLContext *)context;
{
    if (context != [self HTMLContext])
    {
        [_context release]; _context = [context retain];
        [self setContentDOMController:[context rootDOMController]];
    }
}

- (void)registerWebEditorItem:(WEKWebEditorItem *)item;  // recurses through, registering descendants too
{
    // Ensure element is loaded
    DOMDocument *domDoc = [[self webEditor] HTMLDocument];
    if (![item isHTMLElementCreated]) [item loadHTMLElementFromDocument:domDoc];
    //if ([item representedObject]) OBASSERT([item HTMLElement]);
    
    
    //  Populate controller with content. For now, this is simply all the represented objects of all the DOM controllers
    id anObject = [item representedObject];
    if (anObject && //  second bit of this if statement: images are owned by 2 DOM controllers, DON'T insert twice!
        ![[_graphicsController arrangedObjects] containsObjectIdenticalTo:anObject])
    {
        [[self graphicsController] addObject:anObject];
    }
    
    
    // Start observing dependencies
    [item startObservingDependencies];
    
    
    // Register descendants
    for (WEKWebEditorItem *anItem in [item childWebEditorItems])
    {
        [self registerWebEditorItem:anItem];
    }
}

- (void)unregisterWebEditorItem:(WEKWebEditorItem *)item;  // recurses through, registering descendants too
{
    // Turn off dependencies
    [item stopObservingDependencies];
    
    // Unregister descendants
    for (WEKWebEditorItem *anItem in [item childWebEditorItems])
    {
        [self unregisterWebEditorItem:anItem];
    }
}

#pragma mark Selection

- (void)synchronizeLinkManagerWithSelection:(DOMRange *)range;
{
    if (!range)
    {
        SVLink *link = [[self graphicsController] ks_valueForKeyPath:@"selection.plugIn.link"
                                          raisesForNotApplicableKeys:NO];
        
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

- (void)selectObjects:(NSArray *)objects inWebEditor:(WEKWebEditorView *)webEditor;
{
    NSMutableArray *newSelection = [NSMutableArray arrayWithCapacity:[objects count]];
    
    for (id anObject in objects)
    {
        // Possibly have to fall back to forcing selection of not normally selectable item
        id newItem = [[self webEditor] selectableItemForRepresentedObject:anObject];
        if (!newItem) newItem =  [[[self webEditor] contentItem] hitTestRepresentedObject:anObject];
        
        if ([[newItem HTMLElement] ks_isDescendantOfDOMNode:[[newItem HTMLElement] ownerDocument]])
        {
            [newSelection addObject:newItem];
            
            // To select an inline element, the Web Editor or one of its descendants must first be selected
            if ([webEditor shouldTrySelectingDOMElementInline:[newItem HTMLElement]])
            {
                [[[self view] window] makeFirstResponder:webEditor];
            }
        }
        else
        {
            // #83787
            [[self graphicsController] removeSelectedObjects:[NSArray arrayWithObject:anObject]];
        }
    }
    
    [webEditor selectItems:newSelection byExtendingSelection:NO];    // this will feed back to us and the controller in notification
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == sSelectedLinkObservationContext)
    {
        if (!_isChangingSelection)
        {
            [self synchronizeLinkManagerWithSelection:[[self webEditor] selectedDOMRange]];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark Text Areas

- (SVTextDOMController *)textAreaForDOMNode:(DOMNode *)node;
{
    WEKWebEditorItem *controller = [[[self webEditor] contentItem] hitTestDOMNode:node];
    SVTextDOMController *result = [controller textDOMController];
    return result;
}

- (SVTextDOMController *)textAreaForDOMRange:(DOMRange *)range;
{
    OBPRECONDITION(range);
    
    // One day there might be better logic to apply, but for now, testing the start of the range is enough
    return [self textAreaForDOMNode:[range startContainer]];
}

- (WEKWebEditorItem *)articleDOMController;
{
    SVRichText *article = [[[self HTMLContext] page] article];
    WEKWebEditorItem *result = [[[self webEditor] contentItem] hitTestRepresentedObject:article];
    return result;
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
    
    // TODO: this duplicates -[SVSidebarDOMController addGraphic:] somewhat
}

- (IBAction)insertPagelet:(id)sender;
{
    if (![[self firstResponderItem] tryToPerform:_cmd with:sender])
    {
        WEKWebEditorItem *articleController = [self articleDOMController];
        if (![articleController tryToPerform:_cmd with:sender])
        {
            if ([self nextResponder])
            {
                [[self nextResponder] ks_doCommandBySelector:_cmd with:sender];
            }
            else
            {
                NSBeep();
            }
        }
    }
    
    // Hopefully it was a success, so open raw HTML editor if needed
    SVGraphicFactory *factory = [SVGraphicFactory graphicFactoryForTag:[sender tag]];
    if (factory == [SVGraphicFactory rawHTMLFactory])
    {
        [self editRawHTMLInSelectedBlock:sender];
    }
}

- (IBAction)insertFile:(id)sender;
{
    if (![self tryToMakeSelectionPerformAction:_cmd with:sender])
    {
        NSWindow *window = [[self view] window];
        NSOpenPanel *panel = [[[window windowController] document] makeChooseDialog];
        
        [panel beginSheetForDirectory:nil
                                 file:nil
                                types:[SVMediaGraphic allowedTypes]
                       modalForWindow:window
                        modalDelegate:self
                       didEndSelector:@selector(chooseDialogDidEnd:returnCode:contextInfo:)
                          contextInfo:NULL];
    }
}

- (void)chooseDialogDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    if (returnCode == NSCancelButton) return;
    
    
    SVMedia *media = [[SVMedia alloc] initByReferencingURL:[sheet URL]];
    if (!media) return;
    
    
    KTPage *page = [[self HTMLContext] page];
    NSManagedObjectContext *context = [page managedObjectContext];
    
    SVMediaGraphic *graphic = [SVMediaGraphic insertNewGraphicInManagedObjectContext:context];
    [graphic setSourceWithMedia:media];
    [graphic setShowsTitle:NO];
    [graphic setShowsCaption:NO];
    [graphic setShowsIntroduction:NO];
    
    [media release];
    
    [self _insertPageletInSidebar:graphic];
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
    // Get first responder item to do it hopefully
    if (![[[self webEditor] selectedItem] tryToPerform:_cmd with:sender])
    {
        SVSidebarPageletsController *sidebarPageletsController =
        [_graphicsController sidebarPageletsController];
        
        NSUInteger index = [sidebarPageletsController selectionIndex];
        if (index >= NSNotFound) index = 0;
        
        [sidebarPageletsController insertPageletsFromPasteboard:[NSPasteboard generalPasteboard]
                                          atArrangedObjectIndex:index];
    }
}


#pragma mark Graphic Placement

- (void)doPlacementCommandBySelector:(SEL)action;
{
    // Whenever there's some kind of text selection, the responsible controller must take it. If there's no controller, cannot perform
    NSResponder *controller = [self firstResponderItem];
    if (controller)
    {
        [controller doCommandBySelector:action];
    }
    else
    {
        NSBeep();
    }
}

- (void)placeInline:(id)sender;
{
    // Whenever there's some kind of text selection, the responsible controller must take it. If there's no controller, cannot perform
    [self doPlacementCommandBySelector:_cmd];
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

- (void)moveToBlockLevel:(id)sender;
{
    [[self firstResponderItem] tryToPerform:_cmd with:sender];
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

- (SVWebEditorTextRange *)selectedTextRange;
{
    WEKWebEditorView *webEditor = [self webEditor];
    
    DOMRange *domRange = [webEditor selectedDOMRange];
    if (!domRange) return nil;
    
    
    SVWebEditorTextRange *result = nil;
    
    SVTextDOMController *item = [self textAreaForDOMRange:domRange];
    if ([item representedObject])
    {
        result = [SVWebEditorTextRange rangeWithDOMRange:domRange
                                         containerObject:[item representedObject]
                                           containerNode:[item textHTMLElement]];
    }
    
    return result;
}

- (void)setSelectedTextRange:(SVWebEditorTextRange *)textRange affinity:(NSSelectionAffinity)affinity;
{
    OBPRECONDITION(textRange);
    
    WEKWebEditorView *webEditor = [self webEditor];
    
    id item = [[webEditor contentItem] hitTestRepresentedObject:[textRange containerObject]];
    if (item)
    {
        DOMRange *domRange = [[webEditor HTMLDocument] createRange];
        [textRange populateDOMRange:domRange fromContainerNode:[item textHTMLElement]];
        
        [webEditor setSelectedDOMRange:domRange affinity:affinity];
    }
}

- (void)undo_setSelectedTextRange:(SVWebEditorTextRange *)range;
{
    // Ignore if not already marked for update, since that could potentially reset the selection in the distant future, which is very odd for users. Ideally, this situation won't arrise
    // But, er, it does. So I'm commenting it out.
    //if (![self needsUpdate]) return;
    
    
    [_selectionToRestore release]; _selectionToRestore = [range copy];
    
    // Push opposite onto undo stack
    WEKWebEditorView *webEditor = [self webEditor];
    NSUndoManager *undoManager = [webEditor undoManager];
    
    [[undoManager prepareWithInvocationTarget:self]
     undo_setSelectedTextRange:[self selectedTextRange]];
}

- (void)textDOMControllerDidChangeText:(SVTextDOMController *)controller; { }

#pragma mark UI Validation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem;	// WARNING: IF YOU ADD ITEMS HERE, YOU NEED TO SYNCHRONIZE WITH -[KTDocWindowController validateMenuItem:]
{
	VALIDATION((@"%s %@",__FUNCTION__, menuItem));
    BOOL result = YES;		// default to YES so we don't have to do special validation for each action. Some actions might say NO.
    
	SEL action = [menuItem action];
	
	if (action == @selector(editRawHTMLInSelectedBlock:))
	{
		result = NO;	// default to no unless found below.
		for (id selection in [self.graphicsController selectedObjects])
		{
			if ([selection isKindOfClass:[SVRawHTMLGraphic class]])
			{
				result = YES;
				break;
			}
		}
	}
	else if (action == @selector(makeTextLarger:))
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

#pragma mark HTMLEditorController

- (IBAction)editRawHTMLInSelectedBlock:(id)sender;
{
	for (id selection in [self.graphicsController selectedObjects])
	{
		if ([selection isKindOfClass:[SVRawHTMLGraphic class]])
		{
			KTHTMLEditorController *controller = [[[[self view] window] windowController] HTMLEditorController];
			SVRawHTMLGraphic *graphic = (SVRawHTMLGraphic *) selection;
						
			SVTitleBox *titleBox = [graphic titleBox];
			if (titleBox)
			{
				[controller setTitle:[titleBox text]];
			}
			else
			{
				[controller setTitle:nil];
			}
			
			[controller setHTMLSourceObject:graphic];	// so it can save things back.
			
			[controller showWindow:nil];
			break;
		}
	}
}

#pragma mark -

#pragma mark SVSiteItemViewController

- (BOOL)viewShouldAppear:(BOOL)animated webContentAreaController:(SVWebContentAreaController *)controller
{
    _contentAreaController = controller;    // weak ref
    
    KTPage *page = [[controller selectedPage] pageRepresentation];
    
    if (page != [[self HTMLContext] page] &&
        [page master])  // check it looks like a reasonable page to load. #102548
    {
        _reload = NO;
        [self loadPage:page];
        
        // UI-wise it might be better to test if the page contains the HTML loaded into the editor
        // e.g. while editing pagelet in sidebar, it makes sense to leave the editor open
        //self.HTMLEditorController = nil;
    }
    
    return [self viewIsReadyToAppear];
}

#pragma mark -

#pragma mark WebEditorViewDataSource

- (WEKWebEditorItem <SVWebEditorText> *)webEditor:(WEKWebEditorView *)sender
                             textBlockForDOMRange:(DOMRange *)range;
{
    return [self textAreaForDOMRange:range];
}

- (BOOL)webEditor:(WEKWebEditorView *)sender removeItems:(NSArray *)items;
{
    // Maybe the first responder wants to handle it (i.e. if they're in an article)
    if ([[self firstResponderItem] tryToPerform:@selector(deleteObjects:) with:self])
    {
        // Match selection of controller and web editor. Yes, bit of a hacky technique. #101631
        [self willUpdate];
        [self didUpdate];
        
        return YES;
    }
    
    
    
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

- (BOOL)webEditor:(WEKWebEditorView *)sender
       writeItems:(NSArray *)items
     toPasteboard:(NSPasteboard *)pasteboard;
{
    BOOL result = NO;
    
    
    // Want serialized pagelets on pboard
    SVGraphic *graphic = [[items lastObject] representedObject];
    if ([graphic isKindOfClass:[SVGraphic class]])
    {
        result = YES;
        
        [pasteboard addTypes:[NSArray arrayWithObject:kSVGraphicPboardType] owner:nil];
        [graphic writeToPasteboard:pasteboard];
    }
    
    // Place HTML on pasteboard
    //[pasteboard setString:html forType:NSHTMLPboardType];
    //[html release];
    //[pasteboard addTypes:[NSArray arrayWithObject:NSHTMLPboardType] owner:self];
    
    
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
            switch ([proposedSelectedItems count])
            {    
                case 0:
                {
                    // Nothing directly selected, but the range may be inside a selectable element
                    WEKWebEditorItem *item = [sender selectableItemForDOMNode:
                                              [proposedRange commonAncestorContainer]];
                    
                    proposedSelectedItems = (item ? [NSArray arrayWithObject:item] : nil);
                    break;
                }
                    
                case 1:
                {
                    WEKWebEditorItem *item = [proposedSelectedItems objectAtIndex:0];
                    if (![proposedRange ks_selectsNode:[item HTMLElement]]) proposedSelectedItems = nil;
                    break;
                }
                    
                default:
                    proposedSelectedItems = nil;
            }
        }
        else if ([proposedSelectedItems count] == 0)
        {
            proposedSelectedItems = [[self webEditor] editingItems];
        }
        
                                                            
        // Match the controller's selection to the view
        NSArray *objects = [proposedSelectedItems valueForKey:@"representedObject"];
        
        _isChangingSelection = YES;
        result = [[self graphicsController] setSelectedObjects:objects];
        _isChangingSelection = NO;
    }
    
    return result;
}

- (void)webEditorDidChangeSelection:(NSNotification *)notification;
{
    WEKWebEditorView *webEditor = [notification object];
    OBPRECONDITION(webEditor == [self webEditor]);
    
    
    // This used to be done in -…shouldChange… but that often caused WebView to overrite the result moments later
    [self synchronizeLinkManagerWithSelection:[webEditor selectedDOMRange]];
    
    
    // Set our first responder item to match
    DOMRange *selection = [webEditor selectedDOMRange];
    id controller = (selection ? [self textAreaForDOMRange:selection] : nil);
    
    if (!controller)
    {
        NSSet *selectionSet = [[NSSet alloc] initWithArray:[webEditor selectedItems]];
        NSSet *containerControllers = [selectionSet valueForKey:@"textDOMController"];
        
        if ([containerControllers count] == 0)  // fallback to sidebar DOM controller
        {
            containerControllers = [selectionSet valueForKey:@"sidebarDOMController"];
        }
        
        if ([containerControllers count] == 1)
        {
            controller = [containerControllers anyObject];
        }
        
        [selectionSet release];
    }
    [self setFirstResponderItem:controller];
}

- (SVLink *)webEditor:(WEKWebEditorView *)sender willSelectLink:(SVLink *)link;
{
    SVSiteItem *siteItem = [SVSiteItem 
                            siteItemForPreviewPath:[link URLString]
                            inManagedObjectContext:[[[self HTMLContext] page] managedObjectContext]];
    
    if (siteItem)
    {
        link = [SVLink linkWithSiteItem:siteItem openInNewWindow:[link openInNewWindow]];
    }
    
    return link;
}

- (BOOL)webEditor:(WEKWebEditorView *)sender createLink:(SVLinkManager *)actionSender;
{
    if (![sender selectedDOMRange])
    {
        SVLink *link = [actionSender selectedLink];
        [[self graphicsController] setValue:link forKeyPath:@"selection.plugIn.link"];
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
    
    // Load in any subresources. Having to be rather forceful at the moment :(
    if ([[request URL] isEqual:[[dataSource request] URL]])
    {
        for (SVMedia *media in [[self HTMLContext] media])
        {
            if ([media mediaData])
            {
                [dataSource addSubresource:[media webResource]];
            }
        }
    }
    else if ([[[request URL] scheme] isEqualToString:@"svxmedia"])
    {
        NSString *graphicID = [[request URL] ks_lastPathComponent];
        NSManagedObjectContext *context = [[[self HTMLContext] page] managedObjectContext];
        
        NSArray *graphics = [context
                             fetchAllObjectsForEntityForName:@"MediaGraphic"
                             predicate:[NSPredicate predicateWithFormat:@"identifier == %@", graphicID]
                             error:NULL];
        
        if ([graphics count])
        {
            SVMediaGraphic *graphic = [graphics objectAtIndex:0];
            SVMedia *media = [[graphic media] media];
            
            NSMutableURLRequest *result = [[request mutableCopy] autorelease];
            [result setURL:[media mediaURL]];
            request = result;
        }
    }
    else
    {
        for (SVMedia *media in [[self HTMLContext] media])
        {
            WebResource *resource = [media webResource];
            if ([[resource URL] isEqual:[request URL]])
            {
                [dataSource addSubresource:resource];
            }
        }
    }
    
    
    
    if (_reload)
    {
        NSMutableURLRequest *result = [[request mutableCopy] autorelease];
        [result setCachePolicy:NSURLRequestReloadIgnoringCacheData];
        return result;
    }
    else
    {
        return request;
    }
}

- (void)webEditor:(WEKWebEditorView *)sender handleNavigationAction:(NSDictionary *)actionInfo request:(NSURLRequest *)request;
{
    NSURL *URL = [actionInfo objectForKey:@"WebActionOriginalURLKey"];
    
    
    // A link to another page within the document should open that page. Let the delegate take care of deciding how to open it
    KTPage *myPage = [[self HTMLContext] page];
    NSURL *relativeURL = [URL ks_URLRelativeToURL:[myPage URL]];
    NSString *relativePath = [relativeURL relativePath];
    
    if (([[URL scheme] isEqualToString:@"applewebdata"] || [relativePath hasPrefix:kKTPageIDDesignator]) &&
        [[actionInfo objectForKey:WebActionNavigationTypeKey] intValue] != WebNavigationTypeOther)
    {
        SVSiteItem *page = [KTPage siteItemForPreviewPath:relativePath inManagedObjectContext:[myPage managedObjectContext]];
        if (page)
        {
            [[self delegate] webEditorViewController:self openSiteItem:page];
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
         undo_setSelectedTextRange:[self selectedTextRange]];
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
    else if (action == @selector(moveUp:))
    {
        [[self firstResponderItem] doCommandBySelector:@selector(moveObjectUp:)];
    }
    else if (action == @selector(moveDown:))
    {
        [[self firstResponderItem] doCommandBySelector:@selector(moveObjectDown:)];
    }
    else if (action == @selector(reload:))
    {
        [self doCommandBySelector:action];
        return YES;
    }
    
    
    return NO;
}

- (void)webEditor:(WEKWebEditorView *)sender didAddItem:(WEKWebEditorItem *)item;
{
    OBPRECONDITION(sender == [self webEditor]);
    [self registerWebEditorItem:item];
}

- (void)webEditor:(WEKWebEditorView *)sender willRemoveItem:(WEKWebEditorItem *)item;
{
    OBPRECONDITION(sender == [self webEditor]);
    [self unregisterWebEditorItem:item];
}

#pragma mark NSDraggingDestination

- (NSObject *)destinationForDraggingInfo:(id <NSDraggingInfo>)dragInfo;
{
    // Claim all non-textual drags. Specialist stuff like graphics we want though!
    NSArray *types = [NSArray arrayWithObjects:
                      kSVGraphicPboardType,
                      NSURLPboardType,
                      NSFilenamesPboardType,
                      NSStringPboardType, nil];
    
    NSPasteboard *pasteboard = [dragInfo draggingPasteboard];
    NSString *bestType = [pasteboard availableTypeFromArray:types];
    
    if ([bestType isEqualToString:NSStringPboardType])
    {
        return nil;
    }
    
    
    WEKWebEditorView *webEditor = [self webEditor];
    
    NSDictionary *element = [[webEditor webView] elementAtPoint:
                             [webEditor convertPointFromBase:[dragInfo draggingLocation]]];
    
    DOMNode *node = [element objectForKey:WebElementDOMNodeKey];
    
    id result = [[webEditor contentItem] hitTestDOMNode:node
                                     draggingPasteboard:[dragInfo draggingPasteboard]];
    
    // An item may wish for the webview to handle drops. If so, we're not interested
    if (result == [self webView])
    {
        result = nil;
    }
    else if (!result)
    {
        // Don't allow drops of pagelets inside non-page body text
        // This doesn't make sense to me – Mike
        if ([dragInfo draggingSource] == webEditor && [[webEditor draggedItems] count])
        {
            if (![[[[[self textAreaForDOMNode:node] representedObject] entity] name]
                  isEqualToString:@"Article"])
            {
                result = nil;
            }
        }
        
        
        // Fallback to article. #82408
        WEKWebEditorItem *articleController = [self articleDOMController];
        result = [articleController hitTestDOMNode:[articleController HTMLElement]
                                draggingPasteboard:[dragInfo draggingPasteboard]];
        
        if (result == [self webView])
        {
            result = nil;
        }
    }
    
    
    return result;
}

- (NSDragOperation)dragging:(id <NSDraggingInfo>)sender enteredDestination:(NSObject *)destination;
{
    _draggingDestination = destination;
    
    _dropOp = NSDragOperationNone;
    if ([_draggingDestination respondsToSelector:@selector(draggingEntered:)])
    {
        _dropOp = [_draggingDestination draggingEntered:sender];
    }
    return _dropOp;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
{
    return [self dragging:sender enteredDestination:[self destinationForDraggingInfo:sender]];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender;
{
    NSObject *destination = [self destinationForDraggingInfo:sender];
    
    // Switching to a new drag target, so tell the old one drag exited
    if (destination == _draggingDestination)
    {
        if ([_draggingDestination respondsToSelector:@selector(draggingUpdated:)])
        {
            _dropOp = [_draggingDestination draggingUpdated:sender];
        }
        return _dropOp;
    }
    else
    {
        if ([_draggingDestination respondsToSelector:@selector(draggingExited:)])
        {
            [_draggingDestination draggingExited:sender];
        }
        
        return [self dragging:sender enteredDestination:destination];
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
    
    // Ditch the cycle as early as possible to avoid messaging a zombie
    if (![_draggingDestination respondsToSelector:@selector(concludeDragOperation:)] &&
        ![_draggingDestination respondsToSelector:@selector(draggingEnded:)])
    {
        _draggingDestination = nil;
    }
    
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

@end


#pragma mark -


@implementation WEKWebEditorItem (SVWebEditorViewController)

- (NSObject *)hitTestDOMNode:(DOMNode *)node
          draggingPasteboard:(NSPasteboard *)pasteboard;
{
    OBPRECONDITION(node);
    
    NSObject *result = nil;
    
    if ([node ks_isDescendantOfElement:[self HTMLElement]] || ![self HTMLElement])
    {
        for (WEKWebEditorItem *anItem in [self childWebEditorItems])
        {
            result = [anItem hitTestDOMNode:node draggingPasteboard:pasteboard];
            if (result) break;
        }
        
        if (!result)
        {
            NSArray *types = [self registeredDraggedTypes];
            if ([pasteboard availableTypeFromArray:types]) result = self;
        }
    }
    
    return result;
}

@end


