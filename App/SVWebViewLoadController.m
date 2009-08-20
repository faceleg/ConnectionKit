//
//  SVWebViewLoadingController.m
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebViewLoadController.h"
#import "SVWebViewController.h"


@interface SVWebViewLoadController ()
- (void)swapWebViewControllers;
@end


#pragma mark -


@implementation SVWebViewLoadController

static NSString *sWebViewLoadingObservationContext = @"SVWebViewLoadControllerLoadingObservationContext";

- (id)init;
{
    [self initWithTabViewType:NSNoTabsNoBorder];
    
    
    // Create controllers
    _primaryController = [[SVWebViewController alloc] init];
    _secondaryController = [[SVWebViewController alloc] init];
    _webViewLoadingPlaceholder = [[NSViewController alloc] initWithNibName:@"WebViewLoadingPlaceholder"
                                                                    bundle:nil];
    
    [self setViewControllers:[NSArray arrayWithObjects:
                              _primaryController,
                              _secondaryController,
                              _webViewLoadingPlaceholder,
                              nil]
               selectedIndex:2];
    
    
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

#pragma mark Controllers

@synthesize primaryWebViewController = _primaryController;
@synthesize secondaryWebViewController = _secondaryController;

- (void)swapWebViewControllers
{
    // There's no way (or need) to change an individual controller, but we do swap them round after a load
    [self willChangeValueForKey:@"primaryWebViewController"];
    [self willChangeValueForKey:@"secondaryWebViewController"];
    
    SVWebViewController *intermediateControllerVar = _primaryController;
    _primaryController = _secondaryController;
    _secondaryController = intermediateControllerVar;
    
    [self didChangeValueForKey:@"primaryWebViewController"];
    [self didChangeValueForKey:@"secondaryWebViewController"];
}

#pragma mark Page

- (KTPage *)page { return _page; }

- (void)setPage:(KTPage *)page
{
    [page retain];
    [_page release];
    _page = page;
    
    [self setNeedsLoad:YES];
}

#pragma mark Loading

- (void)load;
{
	// Start loading
    SVWebViewController *webViewController = [self secondaryWebViewController];
    NSDate *synchronousLoadEndDate = [[NSDate date] addTimeInterval:0.2];
    [webViewController setPage:[self page]];
	
	
    // Clearly the webview is no longer in need of refreshing
	[self setNeedsLoad:NO];
    
    
    // The webview gets a limited amount of time to load synchronously in, and then we switch to asynchronous
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    while ([webViewController isLoading] && [synchronousLoadEndDate timeIntervalSinceNow] > 0)
    {
        [runLoop runUntilDate:[NSDate distantPast]];
    }
    
    
    // Switch to the loading view
    if ([webViewController isLoading])
    {
        [self setSelectedViewController:_webViewLoadingPlaceholder];    // TODO: avoid ivar
    }
}

- (BOOL)needsLoad { return _needsLoad; }

- (void)setNeedsLoad:(BOOL)flag
{
    if (flag && ![self needsLoad])
	{
		// Install a fresh observer for the end of the run loop
		[[NSRunLoop currentRunLoop] performSelector:@selector(load)
                                             target:self
                                           argument:nil
                                              order:0
                                              modes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
	}
	else if (!flag && [self needsLoad])
	{
		// Unschedule the existing observer and throw it away
		[[NSRunLoop currentRunLoop] cancelPerformSelector:@selector(load)
                                                   target:self
                                                 argument:nil];
	}
    
    _needsLoad = flag;
}

#pragma mark -

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
            [self setSelectedViewController:[self primaryWebViewController]];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
