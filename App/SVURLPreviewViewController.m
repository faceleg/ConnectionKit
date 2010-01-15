//
//  SVURLPreviewViewController.m
//  Sandvox
//
//  Created by Mike on 15/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVURLPreviewViewController.h"


@implementation SVURLPreviewViewController

- (void)loadSiteItem:(SVSiteItem *)item
{
    NSURL *URL = [item URL];
    [[[self webView] mainFrame] loadRequest:[NSURLRequest requestWithURL:URL]];
}

- (void)setDelegate:(id <SVSiteItemViewControllerDelegate>)delegate
{
    //  Ignore for now
}

@end
