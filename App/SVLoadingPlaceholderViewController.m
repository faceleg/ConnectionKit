//
//  SVWebEditorLoadingPlaceholderViewController.m
//  Sandvox
//
//  Created by Mike on 04/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVLoadingPlaceholderViewController.h"

#import "SVWebContentAreaController.h"
#import "SVWebEditorViewController.h"

#import "NSImage+Karelia.h"


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
    SVWebEditorViewController *editorController = [tabController webEditorViewController];
    
    // When loading a new page want white background. But for updating an existing page take a snapshot of the Web Editor
    KTPage *loadedPage = [editorController loadedPage];
    if (!loadedPage || loadedPage != [[editorController HTMLContext] page])
    {
        [[self backgroundImageView] setImage:nil];
    }
    else
    {
        // Take snapshot
        NSView *view = [editorController view];
        [view lockFocus];
        
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

@end
