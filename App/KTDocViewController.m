//
//  KTDocViewController.m
//  Marvel
//
//  Created by Mike on 09/10/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTDocViewController.h"


@implementation KTDocViewController

#pragma mark -
#pragma mark Controller Chain

- (id)parentController { return _parentController; }

- (void)setParentController:(id)controller
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
