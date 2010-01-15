//
//  SVDocContentViewController.m
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebContentAreaController.h"
#import "SVWebSourceViewController.h"
#import "SVLoadingPlaceholderViewController.h"

#import "SVSiteItem.h"
#import "SVSiteItemViewController.h"


static NSString *sWebViewLoadingObservationContext = @"SVWebViewLoadControllerLoadingObservationContext";


@implementation SVWebContentAreaController

- (id)init
{
    [super init];
    
    
    // Create controllers
    _webEditorViewController = [[SVWebEditorViewController alloc] init];
    [_webEditorViewController setDelegate:self];
    [self insertViewController:_webEditorViewController atIndex:0];
    
    
    _sourceViewController = [[SVWebSourceViewController alloc] initWithNibName:@"HTMLSourceView"
                                                               bundle:nil
													   webEditorViewController:_webEditorViewController];
    [self addViewController:_sourceViewController];
    
    
    _placeholderViewController = [[SVLoadingPlaceholderViewController alloc] init];
    [self addViewController:_placeholderViewController];
    
    
    [self setSelectedIndex:0];
    
    
    // Delegation/observation
    [_webEditorViewController addObserver:self
                               forKeyPath:@"updating"
                                  options:0
                                  context:sWebViewLoadingObservationContext];
    
    
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    // We don't support loading any properties from a nib (yet), so jump straight to normal initialisation
    return [self init];
}

- (void)dealloc
{
    // Tear down delegation/observation
    [_webEditorViewController removeObserver:self forKeyPath:@"updating"];
    
    
    [_webEditorViewController release];
    [_placeholderViewController release];
    
    [_selectedPages release];
    
    [super dealloc];
}

#pragma mark Pages

- (NSArray *)selectedPages { return _selectedPages; }

- (void)setSelectedPages:(NSArray *)pages
{
    pages = [pages copy];
    [_selectedPages release];
    _selectedPages = pages;
    
    
    // Update subcontrollers
    switch ([pages count])
    {
        case 0:
            [[_placeholderViewController progressIndicator] stopAnimation:self];
            [[_placeholderViewController label] setStringValue:NSLocalizedString(@"Nothing Selected", @"Selection placeholder")];
            [self setSelectedViewController:_placeholderViewController];
            break;
            
        case 1:
        {
            // Figure out the right view controller to load
            NSViewController <SVSiteItemViewController> *viewController = (id)[self viewControllerForViewType:[self viewType]];
            
            // Start the load here. Once it's finished (or takes too long) we'll switch to the appropriate view
            [viewController loadSiteItem:[pages objectAtIndex:0]];
            [self setSelectedViewController:viewController];
            
            break;
        }
        default:
            [[_placeholderViewController progressIndicator] stopAnimation:self];
            [[_placeholderViewController label] setStringValue:NSLocalizedString(@"Multiple Pages Selected", @"Selection placeholder")];
            [self setSelectedViewController:_placeholderViewController];
            break;
    }
}

#pragma mark View Type

@synthesize viewType = _viewType;
- (void)setViewType:(KTWebViewViewType)type
{
    _viewType = type;
    
    if ([[self selectedPages] count] == 1)
    {
        [self setSelectedViewController:[self viewControllerForViewType:type]];
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
        result = ([menuItem tag] == KTStandardWebView || [menuItem tag] == KTSourceCodeView);
    }
    
    return result;
}

- (NSViewController *)viewControllerForViewType:(KTWebViewViewType)viewType;
{
    NSViewController *result;
    switch (viewType)
    {
        case KTStandardWebView:
        {
            // Figure out the right view controller
            SVSiteItem *item = [[self selectedPages] objectAtIndex:0];
            Class viewControllerClass = [item viewControllerClass];
            
            NSViewController <SVSiteItemViewController> *viewController = nil;
            for (viewController in [self viewControllers])
            {
                if ([viewController isKindOfClass:viewControllerClass]) break;
            }
            if (!viewController)
            {
                // No suitable view controller was found, so create one
                viewController = [[viewControllerClass alloc] init];
                [self addViewController:viewController];
                [viewController release];
            }
            
            result = viewController;
            break;
        }
        case KTSourceCodeView:
        case KTPreviewSourceCodeView:
            result = _sourceViewController;
            break;
            
        default:
            result = nil;
    }
    
    return result;
}

#pragma mark View controllers

@synthesize webEditorViewController = _webEditorViewController;

- (void)switchToLoadingPlaceholderViewIfNeeded
{
    // This method will be called fractionally after the webview has done its first layout, and (hopefully!) before that layout has actually been drawn. Therefore, if the webview is still loading by this point, it was an intermediate load and not suitable for display to the user, so switch over to the placeholder.
    if ([[self webEditorViewController] isUpdating]) 
    {
        [self setSelectedViewController:_placeholderViewController];
        [[_placeholderViewController progressIndicator] startAnimation:self];
    }
}

- (void)didSelectViewController;
{
    [super didSelectViewController];
    
    // Inform delegate of change to title
    [[self delegate] webContentAreaControllerDidChangeTitle:self];
}

#pragma mark Delegate

@synthesize delegate = _delegate;

#pragma mark Inspector

- (id <KSCollectionController>)objectsController;
{
    return [[self webEditorViewController] selectedObjectsController];
}

#pragma mark Web Editor View Controller Delegate

- (void)webEditorViewControllerDidFirstLayout:(SVWebEditorViewController *)sender;
{
    // Being a little bit cunning to make sure we sneak in before views can be drawn
    [[NSRunLoop currentRunLoop] performSelector:@selector(switchToLoadingPlaceholderViewIfNeeded)
                                         target:self
                                       argument:nil
                                          order:(NSDisplayWindowRunLoopOrdering - 1)
                                          modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
}

- (void)webEditorViewController:(SVWebEditorViewController *)sender openPage:(KTPage *)page;
{
    // Take advantag of our binding and set that to the desired page. It will then trigger a change in our selected pages (probably)
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
    if (context == sWebViewLoadingObservationContext)
    {
        if ([self viewType] == KTStandardWebView && ![[self webEditorViewController] isUpdating])
        {
            // The webview is done loading! swap 'em
            [self setSelectedViewController:[self webEditorViewController]];
            
            // The webview is now part of the view hierarchy, so no longer needs to be explicity told its window
            [[[self webEditorViewController] webView] setHostWindow:nil];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
