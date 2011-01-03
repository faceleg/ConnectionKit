//
//  SVWebEditorLoadingPlaceholderViewController.m
//  Sandvox
//
//  Created by Mike on 04/10/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVLoadingPlaceholderViewController.h"

#import "SVWebContentAreaController.h"
#import "SVWebEditorViewController.h"

#import "NSImage+Karelia.h"

#import "YRKSpinningProgressIndicator.h"


@implementation SVLoadingPlaceholderViewController

- (id)init;
{
    return [self initWithNibName:@"LoadingPlaceholder" bundle:nil];
}

- (void)dealloc
{
    [_progressIndicator release];
    [_label release];
    [_imageView release];
    
    [super dealloc];
}

#pragma mark View

- (void)loadView;
{
    [super loadView];
    
    [[self progressIndicator] setColor:[NSColor whiteColor]];
}

@synthesize progressIndicator = _progressIndicator;
- (YRKSpinningProgressIndicator *)progressIndicator
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

@synthesize backgroundImageView = _imageView;
- (NSImageView *)backgroundImageView;
{
    [self view];    // make sure it's loaded
    return _imageView;
}

#pragma mark Presentation

- (void)viewWillAppear:(BOOL)animated;
{
    [super viewWillAppear:animated];
    
    SVWebContentAreaController *tabController = (id)[self parentViewController];    // hack!
    SVWebEditorViewController *webEditorController = [tabController webEditorViewController];
    
    // When loading a new page want white background. But for updating an existing page take a snapshot of the Web Editor
    KTPage *loadedPage = [webEditorController loadedPage];
    if (loadedPage && 
        [tabController selectedViewControllerWhenReady] == webEditorController &&
        loadedPage == [[webEditorController HTMLContext] page])
    {
        // Take snapshot
        NSView *view = [webEditorController view];
        if ([view lockFocusIfCanDraw])
        {
            NSBitmapImageRep *snapshot = [[NSBitmapImageRep alloc]
                                          initWithFocusedViewRect:[view bounds]];
            
            [view unlockFocus];
            
            // Display it
            NSImage *image = [[NSImage alloc] initWithBitmapImageRepresentation:snapshot];
            [snapshot release];
            [[self backgroundImageView] setImage:image];
            [image release];
        }
    }
    else
    {
        [[self backgroundImageView] setImage:nil];
    }
}

@end
