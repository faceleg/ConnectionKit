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

#pragma mark properties

@synthesize viewType = _viewType;
@synthesize webEditorViewController = _webEditorViewController;

#pragma mark Presentation

- (void)updateWithPage:(KTPage *)page;
{    
    NSString *pageHTML = @"";
    if (page)
    {
        switch ([self viewType])
        {
            case KTSourceCodeView:
                pageHTML = [page markupString];
                break;
                
            case KTRSSSourceView:
                pageHTML = [page RSSFeed];
                break;
                
            default:
                break;
        }
    }
    
    NSTextStorage *textStorage = [oSourceView textStorage];
    NSRange fullRange = NSMakeRange(0, [textStorage length]);
    [textStorage replaceCharactersInRange:fullRange withString:pageHTML];
    [oSourceView recolorRange:fullRange];
}

- (void)webEditorViewControllerWillUpdate:(NSNotification *)aNotification
{	
	if ([[self view] window])   // only do something if we are attached to a window
	{
		[self updateWithPage:[self.webEditorViewController page]];
	}
}

- (BOOL)viewShouldAppear:(BOOL)animated
webContentAreaController:(SVWebContentAreaController *)controller
{
    [self setViewType:[controller viewType]];   // copy across for use during updates
    [self updateWithPage:(KTPage *)[controller selectedPage]];
    return YES;
}

@end
