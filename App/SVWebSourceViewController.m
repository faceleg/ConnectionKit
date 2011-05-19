//
//  SVWebSourceViewController.m
//  Sandvox
//
//  Created by Dan Wood on 1/5/10.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
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
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:sSVWebEditorViewControllerWillUpdateNotification
												  object:self.webEditorViewController];
	self.currentPage = nil;
	self.webEditorViewController = nil;
	[super dealloc];
}

#pragma mark properties

- (NSTextView *)sourceView;
{
    [self view];
    return oSourceView;
}

@synthesize viewType = _viewType;
@synthesize webEditorViewController = _webEditorViewController;
@synthesize currentPage = _currentPage;

#pragma mark Presentation

- (void)updateWithPage:(KTPage *)page;
{
	self.currentPage = page;
    NSString *pageHTML = @"";
    if (page)
    {
        switch ([self viewType])
        {
            case KTSourceCodeView:
                pageHTML = [page markupString];
                break;
                
			case KTPreviewSourceCodeView:
                pageHTML = [page markupStringForEditing];
                break;
                
			case KTRSSSourceView:
                pageHTML = [page RSSFeed];
                break;
                
            default:
                break;
        }
    }
    
    NSTextStorage *textStorage = [[self sourceView] textStorage];
    NSRange fullRange = NSMakeRange(0, [textStorage length]);
    [textStorage replaceCharactersInRange:fullRange withString:pageHTML];
    [[self sourceView] recolorRange:NSMakeRange(0, [pageHTML length])];
}

- (void)webEditorViewControllerWillUpdate:(NSNotification *)aNotification
{	
	if ([[self view] window])   // only do something if we are attached to a window
	{
		[self updateWithPage:self.webEditorViewController.HTMLContext.page];
	}
}

- (BOOL)viewShouldAppear:(BOOL)animated
webContentAreaController:(SVWebContentAreaController *)controller
{
    [self setViewType:[controller viewType]];   // copy across for use during updates
	self.currentPage = (KTPage *)[controller selectedPage];
    [self updateWithPage:self.currentPage];
    return YES;
}

- (IBAction)reload:(id)sender
{
	[self updateWithPage:self.currentPage];
}

@end
