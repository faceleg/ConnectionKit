//
//  SVURLPreviewViewController.m
//  Sandvox
//
//  Created by Mike on 15/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVURLPreviewViewController.h"

#import "KSTabViewController.h"


@interface SVURLPreviewViewController ()
@property(nonatomic, readwrite) BOOL viewIsReadyToAppear;
@end


#pragma mark -


@implementation SVURLPreviewViewController


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
    NSURL *URL = [item URL];
    [[[self webView] mainFrame] loadRequest:[NSURLRequest requestWithURL:URL]];
}

@synthesize delegate = _delegate;

@end
