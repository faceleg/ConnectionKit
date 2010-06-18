//
//  SVDocContentViewController.m
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebContentAreaController.h"
#import "SVURLPreviewViewController.h"
#import "SVWebSourceViewController.h"
#import "SVLoadingPlaceholderViewController.h"

#import "KTPage.h"
#import "SVSiteItemViewController.h"


static NSString *sWebContentReadyToAppearObservationContext = @"SVItemViewControllerIsReadyToAppear";


@implementation SVWebContentAreaController

- (void)prepareContent;
{
    // Create controllers
    _webEditorViewController = [[SVWebEditorViewController alloc] init];
    [_webEditorViewController setDelegate:self];
    [self addViewController:_webEditorViewController];
    
    
    _webPreviewController = [[SVURLPreviewViewController alloc] init];
    [self addViewController:_webPreviewController];
    
    _sourceViewController = [[SVWebSourceViewController alloc] initWithNibName:@"HTMLSourceView"
                                                                        bundle:nil
													   webEditorViewController:_webEditorViewController];
    [self addViewController:_sourceViewController];
    
    
    _placeholderViewController = [[SVLoadingPlaceholderViewController alloc] init];
    [self addViewController:_placeholderViewController];
    
    
    [self setSelectedIndex:0];
    
    
    // Delegation/observation
    [_webEditorViewController addObserver:self
                               forKeyPath:@"viewIsReadyToAppear"
                                  options:0
                                  context:sWebContentReadyToAppearObservationContext];
    [_webPreviewController addObserver:self
                            forKeyPath:@"viewIsReadyToAppear"
                               options:0
                               context:sWebContentReadyToAppearObservationContext];
}

- (id)init
{
    [super init];
    
    
    [self prepareContent];
    
    
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    [self prepareContent];
    return self;
}

- (void)dealloc
{
    // Tear down delegation/observation
    [_webEditorViewController removeObserver:self forKeyPath:@"viewIsReadyToAppear"];
    [_webPreviewController removeObserver:self forKeyPath:@"viewIsReadyToAppear"];
    
    
    [_webEditorViewController release];
    [_sourceViewController release];
    [_placeholderViewController release];
    
    [_selectedPages release];
    
    [super dealloc];
}

#pragma mark General 

- (void)didChangeSelectionOrViewType
{
    // Update subcontrollers
    NSArray *pages = [self selectedPages];
    switch ([pages count])
    {
        case 0:
            [[_placeholderViewController progressIndicator] stopAnimation:self];
            [[_placeholderViewController label] setStringValue:NSLocalizedString(@"Nothing Selected", @"Selection placeholder")];
            [self setSelectedViewControllerWhenReady:nil];
            break;
            
        case 1:
        {
            // Figure out the right view controller to load
            SVSiteItem *item = [pages objectAtIndex:0];
            
            NSViewController <SVSiteItemViewController> *viewController = [self viewControllerForSiteItem:item];
            
            // Start the load here. Present the view if it's ready; if not wait until it is (or takes too long)
            [viewController loadSiteItem:item];
            [self setSelectedViewControllerWhenReady:viewController];
            
            break;
        }
        default:
            [[_placeholderViewController progressIndicator] stopAnimation:self];
            [[_placeholderViewController label] setStringValue:NSLocalizedString(@"Multiple Pages Selected", @"Selection placeholder")];
            [self setSelectedViewControllerWhenReady:nil];
            break;
    }
}

#pragma mark Pages

- (NSArray *)selectedPages { return _selectedPages; }

- (void)setSelectedPages:(NSArray *)pages
{
    pages = [pages copy];
    [_selectedPages release];
    _selectedPages = pages;
    
    
    [self didChangeSelectionOrViewType];
}

#pragma mark View Type

@synthesize viewType = _viewType;
- (void)setViewType:(KTWebViewViewType)type
{
    _viewType = type;
    
    if ([[self selectedPages] count] == 1)
    {
        [self didChangeSelectionOrViewType];
    }
}

- (IBAction)selectWebViewViewType:(id)sender;
{
    KTWebViewViewType viewType = [sender tag];
	if (viewType == [self viewType])
	{
		viewType = KTStandardWebView;
	}
	
	[self setViewType:viewType];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    BOOL result = YES;
    
    if ([menuItem action] == @selector(selectWebViewViewType:))
    {
        // Tick the selected state
        [menuItem setState:([menuItem tag] == [self viewType])];
        
        
        // Only allow the user to select standard and source code view for now.
        KTPage *page = ([[self selectedPages] count] == 1 ?
                        [[self selectedPages] objectAtIndex:0] :
                        nil);
        
        result = ([menuItem tag] == KTStandardWebView ||
                  [menuItem tag] == KTSourceCodeView ||
                  ([menuItem tag] == KTRSSSourceView && [[page collectionSyndicate] boolValue]));
    }
    
    return result;
}

#pragma mark View controllers

@synthesize webEditorViewController = _webEditorViewController;

- (void)presentLoadingViewController;
{
    [self setSelectedViewController:_placeholderViewController];
    [[_placeholderViewController progressIndicator] startAnimation:self];
}

- (NSViewController <SVSiteItemViewController> *)viewControllerForSiteItem:(SVSiteItem *)item;
{
    NSViewController <SVSiteItemViewController> *result = nil;
    
    
    KTPage *page = [item pageRepresentation];
    if (page)
    {
        switch ([self viewType])
        {
            case KTStandardWebView:
            {
                // Figure out the right view controller
                result = [self webEditorViewController];
                break;
            }
            case KTSourceCodeView:
            case KTPreviewSourceCodeView:
                result = _sourceViewController;
                break;
                
            default:
                result = nil;
        }
    }
    else
    {
        result = _webPreviewController;
    }
    
    return result;
}

#pragma mark Selected View Controller

@synthesize selectedViewControllerWhenReady = _selectedViewControllerWhenReady;
- (void)setSelectedViewControllerWhenReady:(NSViewController <SVSiteItemViewController> *) controller;
{
    // Store
    _selectedViewControllerWhenReady = controller;
    
    
    //  Either the view's ready to appear, or we need to wait until it really is
    if ([controller viewIsReadyToAppear])
    {
        [self setSelectedViewController:controller];
    }
    else
    {
        [self performSelector:@selector(siteViewControllerSelectionMayHaveTimedOut) withObject:nil afterDelay:0.25];
    }
}

- (void)siteViewControllerSelectionMayHaveTimedOut
{
    if ([self selectedViewController] != [self selectedViewControllerWhenReady])
    {
        [self presentLoadingViewController];
    }
}

#pragma mark Delegate

@synthesize delegate = _delegate;

#pragma mark Inspector

- (id <KSCollectionController>)objectsController;
{
    return [[self webEditorViewController] selectedObjectsController];
}

#pragma mark Web Editor View Controller Delegate

- (void)webEditorViewController:(SVWebEditorViewController *)sender openPage:(KTPage *)page;
{
    // Take advantage of our binding and set that to the desired page. It will then trigger a change in our selected pages (probably)
    if (page)
    {
        NSDictionary *bindingInfo = [self infoForBinding:@"selectedPages"];
        if (bindingInfo)
        {
            id object = [bindingInfo objectForKey:NSObservedObjectKey];
            NSString *keyPath = [bindingInfo objectForKey:NSObservedKeyPathKey];
            [object setValue:[NSArray arrayWithObject:page] forKeyPath:keyPath];
        }
    }
}

- (void)siteItemViewControllerShowSourceView:(NSViewController <SVSiteItemViewController> *)viewController
{
    [self setViewType:KTSourceCodeView];
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == sWebContentReadyToAppearObservationContext)
    {
        if (object == [self selectedViewControllerWhenReady])
        {
            if ([object viewIsReadyToAppear])
            {
                // The webview is done loading! swap 'em
                [self setSelectedViewController:object];
                
                // The webview is now part of the view hierarchy, so no longer needs to be explicity told its window
                [[[self webEditorViewController] webView] setHostWindow:nil];
            }
            else
            {
                [self presentLoadingViewController];
            }
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
