//
//  SVWebEditorLoadingPlaceholderViewController.m
//  Sandvox
//
//  Created by Mike on 04/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVLoadingPlaceholderViewController.h"


@implementation SVLoadingPlaceholderViewController

- (id)init;
{
    if (self = [self initWithNibName:@"WebViewLoadingPlaceholder" bundle:nil])
    {
        
    }
    
    return self;
}

- (void)loadView
{
    [super loadView];
    
    [[self progressIndicator] startAnimation:self];
}

@synthesize progressIndicator = _progressIndicator;

@end
