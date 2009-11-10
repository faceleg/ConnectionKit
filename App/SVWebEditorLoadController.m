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

#import "KTPage.h"
#import "SVWebEditorHTMLContext.h"


@interface SVWebEditorLoadController ()
- (void)swapWebViewControllers;
@end


#pragma mark -


@implementation SVWebEditorLoadController

static NSString *sWebViewLoadingObservationContext = @"SVWebViewLoadControllerLoadingObservationContext";
static NSString *sWebViewDependenciesObservationContext = @"SVWebViewDependenciesObservationContext";


- (id)init;
{
    [self initWithTabViewType:NSNoTabsNoBorder];
    
    
    // Create controllers
    _primaryController = [[SVWebEditorViewController alloc] init];
    [_primaryController setDelegate:self];
    [self insertViewController:_primaryController atIndex:0];
    
    _secondaryController = [[SVWebEditorViewController alloc] init];
    [_secondaryController setDelegate:self];
    [self insertViewController:_secondaryController atIndex:1];
    
    _webViewLoadingPlaceholder = [[SVLoadingPlaceholderViewController alloc] init];
    [self insertViewController:_webViewLoadingPlaceholder atIndex:2];
    [self setSelectedIndex:2];
    
    
    // Delegation/observation
    [_primaryController addObserver:self
                         forKeyPath:@"loading"
                            options:0
                            context:sWebViewLoadingObservationContext];
    [_secondaryController addObserver:self
                           forKeyPath:@"loading"
                              options:0
                              context:sWebViewLoadingObservationContext];
    
    
    return self;
}

- (void)dealloc
{
    // Tear down delegation/observation
    [_primaryController removeObserver:self forKeyPath:@"loading"];
    [_secondaryController removeObserver:self forKeyPath:@"loading"];
    
    
    [_primaryController release];
    [_secondaryController release];
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

@synthesize primaryWebViewController = _primaryController;
@synthesize secondaryWebViewController = _secondaryController;

- (void)swapWebViewControllers
{
    // There's no way (or need) to change an individual controller, but we do swap them round after a load.
    [self willChangeValueForKey:@"primaryWebViewController"];
    [self willChangeValueForKey:@"secondaryWebViewController"];
    
    SVWebEditorViewController *intermediateControllerVar = _primaryController;
    _primaryController = _secondaryController;
    _secondaryController = intermediateControllerVar;
    
    [self didChangeValueForKey:@"primaryWebViewController"];
    [self didChangeValueForKey:@"secondaryWebViewController"];
    
    
    if ([[self primaryWebViewController] page] == [[self secondaryWebViewController] page])
    {
        //  Copying across scrollpoint
        NSRect visibleRect = [[[[self secondaryWebViewController] webEditorView] documentView] visibleRect];
        [[[self primaryWebViewController] webEditorView] scrollToPoint:visibleRect.origin];
        
        
        // Copy across selection
        
    }
    
    
    // Bring the new primary controller to the front
    [self setSelectedViewController:[self primaryWebViewController]];
}

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

#pragma mark Loading

- (void)load;
{
	// Tear down old dependencies
    for (KSObjectKeyPathPair *aDependency in _pageDependencies)
    {
        [[aDependency object] removeObserver:self
                                  forKeyPath:[aDependency keyPath]];
    }
    
    
    // Start loading. Some parts of WebKit need to be attached to a window to work properly, so we need to provide one while it's loading in the background. It will be removed again after has finished since the webview will be properly part of the view hierarchy
    SVWebEditorViewController *webViewController = [self secondaryWebViewController];
    
    NSDate *synchronousLoadEndDate = [[NSDate date] addTimeInterval:0.2];
    
    [[webViewController webView] setHostWindow:[[self view] window]];   // TODO: Our view may be outside the hierarchy too; it woud be better to figure out who our window controller is and use that.
    [webViewController setPage:[self page]];
    
    
    // Build the HTML.
	SVWebEditorHTMLContext *context = [[SVWebEditorHTMLContext alloc] init];
    [context setCurrentPage:[self page]];
    [context setGenerationPurpose:kGeneratingPreview];
	//[parser setIncludeStyling:([self viewType] != KTWithoutStylesView)];
    
    [SVHTMLContext pushContext:context];
	NSString *pageHTML = [[self page] HTMLString];
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
    
    
    // The webview gets a limited amount of time to load synchronously in, and then we switch to asynchronous
    BOOL loaded = [[webViewController webEditorView] loadUntilDate:synchronousLoadEndDate];
    if (!loaded)
    {
        [self setSelectedViewController:_webViewLoadingPlaceholder];    // TODO: avoid ivar
    }
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
        if (object == [self secondaryWebViewController] &&
            ![[self secondaryWebViewController] isLoading])
        {
            // The webview is done loading! swap 'em
            [self swapWebViewControllers];
            
            // The webview is now part of the view hierarchy, so no longer needs to be explicity told its window
            [[[self primaryWebViewController] webView] setHostWindow:nil];
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

- (void)webEditorViewController:(SVWebEditorViewController *)sender openPage:(KTPage *)page;
{
    // Only want to do as asked if the controller is the one currently visible. Otherwise it could come as a bit of a surprise!
    if (sender == [self selectedViewController])
    {
        [[self delegate] loadController:self openPage:page];
    }
}

@end
