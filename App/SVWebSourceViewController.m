//
//  SVWebSourceViewController.m
//  Sandvox
//
//  Created by Dan Wood on 1/5/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVWebSourceViewController.h"
#import "SVWebEditorViewController.h"
#import "SVWebEditorHTMLContext.h"
#import "KTPage.h"
#import "NSTextView+KTExtensions.h"

@implementation SVWebSourceViewController

@synthesize webEditorViewController = _webEditorViewController;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil webEditorViewController:(SVWebEditorViewController *)aWebEditorViewController;
{
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if ( self != nil )
	{
		self.webEditorViewController = aWebEditorViewController;
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(webEditorViewControllerWillUpdate:)
													 name:sSVWebEditorViewControllerWillUpdateNotification
												   object:aWebEditorViewController];		// only match updates from that controller
	}
	return self;
}

- (void) dealloc
{
	self.webEditorViewController = nil;
	[super dealloc];
}




- (void)webEditorViewControllerWillUpdate:(NSNotification *)aNotification
{	
	if ([[self view] window] || nil == aNotification)		// only do something if we are attached to a window or this is a forced notification
	{
		KTPage *page = [self.webEditorViewController page];
		
		NSString *pageHTML = (page) ? [page markupString] : @"";
		
		NSTextStorage *textStorage = [oSourceView textStorage];
		NSRange fullRange = NSMakeRange(0, [textStorage length]);
		[textStorage replaceCharactersInRange:fullRange withString:pageHTML];
		[oSourceView recolorRange:fullRange];
	}
}

- (void)loadView;
{
	[super loadView];
}

- (BOOL)viewShouldAppear:(BOOL)animated
webContentAreaController:(SVWebContentAreaController *)controller
{
    return YES;
}

- (void)viewWillAppear:(BOOL)animated;
{
	[self webEditorViewControllerWillUpdate:nil];
}

@end
