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


- (id)init;
{
    [self initWithTabViewType:NSNoTabsNoBorder];
    
    
    // Create controllers
    _webEditorViewController = [[SVWebEditorViewController alloc] init];
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
