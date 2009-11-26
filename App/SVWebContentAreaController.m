//
//  SVDocContentViewController.m
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebContentAreaController.h"

#import "SVLoadingPlaceholderViewController.h"


static NSString *sWebViewLoadingObservationContext = @"SVWebViewLoadControllerLoadingObservationContext";


@implementation SVWebContentAreaController

- (id)init
{
    [super init];
    
    
    // Create controllers
    _webEditorViewController = [[SVWebEditorViewController alloc] init];
    [_webEditorViewController setDelegate:self];
    [self insertViewController:_webEditorViewController atIndex:0];
    
    
    _sourceViewController = [[NSViewController alloc] initWithNibName:@"HTMLSourceView"
                                                               bundle:nil];
    [self addViewController:_sourceViewController];
    
    
    _placeholderViewController = [[SVLoadingPlaceholderViewController alloc] init];
    [self addViewController:_placeholderViewController];
    
    
    [self setSelectedIndex:0];
    
    
    // Delegation/observation
    [_webEditorViewController addObserver:self
                               forKeyPath:@"loading"
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
    [_webEditorViewController removeObserver:self forKeyPath:@"loading"];
    
    
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
    NSViewController *controller;
    switch ([pages count])
    {
        case 0:
            [[_placeholderViewController label] setStringValue:NSLocalizedString(@"Nothing Selected", @"Selection placeholder")];
            controller = _placeholderViewController;
            break;
            
        case 1:
            [[self webEditorViewController] setPage:[pages objectAtIndex:0]];
            controller = [self viewControllerForViewType:[self viewType]];
            break;
            
        default:
            [[_placeholderViewController label] setStringValue:NSLocalizedString(@"Multiple Pages Selected", @"Selection placeholder")];
            controller = _placeholderViewController;
            break;
    }
    
    [self setSelectedViewController:controller];
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
            result = [self webEditorViewController];
            break;
            
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
    if ([[self webEditorViewController] isLoading]) 
    {
        [self setSelectedViewController:_placeholderViewController];
        [[_placeholderViewController progressIndicator] startAnimation:self];
    }
}

- (void)didSelectViewController;
{
    [super didSelectViewController];
    
    // Inform delegate of change to title
    NSString *title = nil;
    if ([self selectedViewController] == [self webEditorViewController])
    {
        title = [[self webEditorViewController] title];
    }
    [[self delegate] webContentAreaControllerDidChangeTitle:self];
}

#pragma mark Delegate

@synthesize delegate = _delegate;

#pragma mark Inspector

- (id <KSCollectionController>)objectsController;
{
    return [[self webEditorViewController] contentController];
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

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == sWebViewLoadingObservationContext)
    {
        if (![[self webEditorViewController] isLoading])
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
