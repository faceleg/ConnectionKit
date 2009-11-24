//
//  SVWebViewLoadingController.m
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorLoadController.h"
#import "SVWebEditorViewController.h"
#import "SVLoadingPlaceholderViewController.h"

#import "SVHTMLTextBlock.h"
#import "KTPage.h"
#import "SVPageletBody.h"
#import "SVWebEditorHTMLContext.h"

#import "KSCollectionController.h"


@interface SVWebEditorLoadController ()
@end


#pragma mark -


@implementation SVWebEditorLoadController

static NSString *sWebViewLoadingObservationContext = @"SVWebViewLoadControllerLoadingObservationContext";
static NSString *sWebViewDependenciesObservationContext = @"SVWebViewDependenciesObservationContext";


- (id)init;
{
    [self initWithTabViewType:NSNoTabsNoBorder];
    
    
    // Create controllers
    _selectableObjectsController = [[NSArrayController alloc] init];
    [_selectableObjectsController setAvoidsEmptySelection:NO];
    [_selectableObjectsController setObjectClass:[NSObject class]];
    
    
    _webEditorViewController = [[SVWebEditorViewController alloc] init];
    [_webEditorViewController setContentController:[self selectableObjectsController]];
    [_webEditorViewController setDelegate:self];
    [self insertViewController:_webEditorViewController atIndex:0];
    
    
    _webViewLoadingPlaceholder = [[SVLoadingPlaceholderViewController alloc] init];
    [self insertViewController:_webViewLoadingPlaceholder atIndex:1];
    
    [self setSelectedViewController:_webEditorViewController];
    
    
    // Delegation/observation
    [_webEditorViewController addObserver:self
                         forKeyPath:@"loading"
                            options:0
                            context:sWebViewLoadingObservationContext];
    
    
    return self;
}

- (void)dealloc
{
    // Tear down delegation/observation
    [_webEditorViewController removeObserver:self forKeyPath:@"loading"];
    
    
    [_webEditorViewController release];
    [_webViewLoadingPlaceholder release];
    
    [super dealloc];
}

#pragma mark Title

- (void)setTitle:(NSString *)title
{
    [super setTitle:title];
    
    [[self delegate] loadControllerDidChangeTitle:self];
}

#pragma mark Controllers

@synthesize webEditorViewController = _webEditorViewController;

- (void)didSelectViewController;
{
    [super didSelectViewController];
    
    // Update our title to match the new selection
    [self setTitle:[[self selectedViewController] title]];
}

#pragma mark Page

- (KTPage *)page { return _page; }

- (void)setPage:(KTPage *)page
{
    [page retain];
    [_page release];
    _page = page;
    
    [self setNeedsLoad];
}

@synthesize selectableObjectsController = _selectableObjectsController;

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
    SVWebEditorViewController *webViewController = [self webEditorViewController];
        
    [[webViewController webView] setHostWindow:[[self view] window]];   // TODO: Our view may be outside the hierarchy too; it woud be better to figure out who our window controller is and use that.
    [webViewController setPage:[self page]];
    
    
    [webViewController loadHTMLString:pageHTML];
	[SVHTMLContext popContext];
    
    
    // Observe the used keypaths
    [_pageDependencies release], _pageDependencies = [[context dependencies] copy];
    for (KSObjectKeyPathPair *aDependency in _pageDependencies)
    {
        [[aDependency object] addObserver:self
                               forKeyPath:[aDependency keyPath]
                                  options:0
                                  context:sWebViewDependenciesObservationContext];
    }
    [context release];
    
	
    // Clearly the webview is no longer in need of refreshing
	_needsLoad = NO;
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

- (void)switchToLoadingPlaceholderViewIfNeeded
{
    // This method will be called fractionally after the webview has done its first layout, and (hopefully!) before that layout has actually been drawn. Therefore, if the webview is still loading by this point, it was an intermediate load and not suitable for display to the user, so switch over to the placeholder.
    if ([[self webEditorViewController] isLoading]) 
    {
        [self setSelectedViewController:_webViewLoadingPlaceholder];
    }
}

#pragma mark Delegate

@synthesize delegate = _delegate;

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
    else if (context == sWebViewDependenciesObservationContext)
    {
        [self setNeedsLoad];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark SVWebEditorViewControllerDelegate

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
    // Only want to do as asked if the controller is the one currently visible. Otherwise it could come as a bit of a surprise!
    if (sender == [self selectedViewController])
    {
        [[self delegate] loadController:self openPage:page];
    }
}

@end
