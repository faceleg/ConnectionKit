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

@implementation SVWebSourceViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil webEditorViewController:(SVWebEditorViewController *)aWebEditorViewController;
{
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if ( self != nil )
	{
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(webEditorViewControllerWillUpdate:)
													 name:sSVWebEditorViewControllerWillUpdateNotification
												   object:aWebEditorViewController];		// only match updates from that controller
	}
	return self;
}

- (void) webEditorViewControllerWillUpdate:(NSNotification *)aNotification
{
	NSLog(@"webEditorViewControllerWillUpdate %@", [aNotification object]);
	
	SVWebEditorViewController *editorController = [aNotification object];
	KTPage *page = [editorController page];
	
	NSString *pageHTML = [page HTMLString];
	
	NSTextStorage *textStorage = [oSourceView textStorage];
	[textStorage replaceCharactersInRange:NSMakeRange(0, [textStorage length]) withString:pageHTML];
}

@end
