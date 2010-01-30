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

#import "NSString+Karelia.h"


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

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
    if (frame == [sender mainFrame])
    {
        [frame loadAlternateHTMLString:@"FAIL" baseURL:nil forUnreachableURL:nil];
    }
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)errorf orFrame:(WebFrame *)frame
{
    
}

- (void)webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame
{
    if (frame == [sender mainFrame])
    {
        [self setTitle:title];
    }
}

#pragma mark Presentation

@synthesize viewIsReadyToAppear = _readyToAppear;

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    // Did we move because of an in-progress load?
    if (![[self webView] isLoading]) [self loadSiteItem:nil];
    
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
    if (item)
    {
        [item addObserver:self
               forKeyPath:@"URL" 
                  options:NSKeyValueObservingOptionInitial
                  context:sURLPreviewViewControllerURLObservationContext];
        [item addObserver:self
               forKeyPath:@"mediaRepresentation" 
                  options:NSKeyValueObservingOptionInitial
                  context:sURLPreviewViewControllerURLObservationContext];
    }
    else
    {
        [[self webView] close];
        [self setWebView:nil];
        [self setView:nil];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == sURLPreviewViewControllerURLObservationContext)
    {
        // Display best representation
        id <SVMedia> media = [object mediaRepresentation];
        if (media)
        {
            NSURL *URL = [[object mediaRepresentation] fileURL];
            if (!URL)
            {
                NSString *filename = [media preferredFilename];
                NSString *type = [NSString UTIForFilenameExtension:[filename pathExtension]];
                
                [[[self webView] mainFrame] loadData:[media fileContents]
                                            MIMEType:[NSString MIMETypeForUTI:type]
                                    textEncodingName:nil
                                             baseURL:[object URL]];
            }
            else
            {
                [[[self webView] mainFrame] loadRequest:[NSURLRequest requestWithURL:URL]];
            }
        }
        else
        {
            [[[self webView] mainFrame] loadRequest:[NSURLRequest requestWithURL:[object URL]]];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark Delegate

@synthesize delegate = _delegate;

@end
