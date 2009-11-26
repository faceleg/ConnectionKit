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
    return [self initWithNibName:@"LoadingPlaceholder" bundle:nil];
}

@synthesize progressIndicator = _progressIndicator;
- (NSProgressIndicator *)progressIndicator
{
    [self view];    // make sure it's loaded
    return _progressIndicator;
}

@synthesize label = _label;
- (NSTextField *)label
{
    [self view];    // make sure it's loaded
    return _label;
}

@end
