//
//  KTDocViewController.m
//  Marvel
//
//  Created by Mike on 09/10/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTDocViewController.h"


@implementation KTDocViewController

- (void)dealloc
{
    [self setView:nil]; // Removes us from responder chain and releases view
    
    [super dealloc];
}

#pragma mark -
#pragma mark View

- (NSView *)view { return view; }

- (void)setView:(NSView *)aView
{
    // Store view
	[aView retain];
	[view release];
	view = aView;
}

#pragma mark -
#pragma mark Controller Chain

- (id <KTDocumentControllerChain>)parentController { return _parentController; }

- (void)setParentController:(id <KTDocumentControllerChain>)controller
{
    _parentController = controller; // Weak ref
    [self setWindowController:[controller windowController]];
    [self setDocument:[controller document]];
}

- (KTDocWindowController *)windowController { return _windowController; }

- (void)setWindowController:(KTDocWindowController *)aWindowController
{
	_windowController = aWindowController;  // Weak ref
}

- (KTDocument *)document { return _document; }

- (void)setDocument:(KTDocument *)document
{
    _document = document;   // Weak ref
}


@end
