//
//  SVWebSourceViewController.m
//  Sandvox
//
//  Created by Dan Wood on 1/5/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVWebSourceViewController.h"
#import "SVWebEditorViewController.h"


@implementation SVWebSourceViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil;
{
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if ( self != nil )
	{
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(webEditorViewControllerWillUpdate:)
													 name:sSVWebEditorViewControllerWillUpdateNotification
												   object:nil];
	}
	return self;
}

- (void) webEditorViewControllerWillUpdate:(NSNotification *)aNotification
{
	NSLog(@"webEditorViewControllerWillUpdate %@", [aNotification object]);
}

@end
