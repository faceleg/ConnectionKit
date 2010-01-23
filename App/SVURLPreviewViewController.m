//
//  SVURLPreviewViewController.m
//  Sandvox
//
//  Created by Mike on 15/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVURLPreviewViewController.h"

#import "SVMediaProtocol.h"
#import "SVSiteItem.h"

#import "KSTabViewController.h"


static NSString *sURLPreviewViewControllerURLObservationContext = @"URLPreviewViewControllerURLObservation";


@interface SVURLPreviewViewController ()
@property(nonatomic, readwrite) BOOL viewIsReadyToAppear;
@end


#pragma mark -


@implementation SVURLPreviewViewController

- (void)dealloc
{
    [self setSiteItem:nil];
    [super dealloc];
}

#pragma mark View

- (void)setWebView:(WebView *)webView
{
    [super setWebView:webView];
    [webView setFrameLoadDelegate:self];
}

- (void)webView:(WebView *)sender didCommitLoadForFrame:(WebFrame *)frame;
{
    [self setViewIsReadyToAppear:YES];
}

#pragma mark Presentation

@synthesize viewIsReadyToAppear = _readyToAppear;

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    //  Once the view goes offscreen, it's not ready to be displayed again until after loading has progressed a little
    [self setViewIsReadyToAppear:NO];
}

#pragma mark Loading

- (void)loadSiteItem:(SVSiteItem *)item
{
    [self setSiteItem:item];
}

@synthesize siteItem = _siteItem;
- (void)setSiteItem:(SVSiteItem *)item
{
    // teardown
    [_siteItem removeObserver:self forKeyPath:@"URL"];
    [_siteItem removeObserver:self forKeyPath:@"mediaRepresentation"];
    
    item = [item retain];
    [_siteItem release]; _siteItem = item;
    
    // observe new
    [item addObserver:self
           forKeyPath:@"URL" 
              options:NSKeyValueObservingOptionInitial
              context:sURLPreviewViewControllerURLObservationContext];
    [item addObserver:self
           forKeyPath:@"mediaRepresentation" 
              options:NSKeyValueObservingOptionInitial
              context:sURLPreviewViewControllerURLObservationContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == sURLPreviewViewControllerURLObservationContext)
    {
        // Display best representation
        NSURL *URL = [[object mediaRepresentation] fileURL];
        if (!URL) URL = [object URL];
        
        [[[self webView] mainFrame] loadRequest:[NSURLRequest requestWithURL:URL]];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark Delegate

@synthesize delegate = _delegate;

@end
