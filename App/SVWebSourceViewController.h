//
//  SVWebSourceViewController.h
//  Sandvox
//
//  Created by Dan Wood on 1/5/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVSiteItemViewController.h"

@class SVWebEditorViewController;

@interface SVWebSourceViewController : NSViewController <SVSiteItemViewController> {

	IBOutlet NSTextView *oSourceView;
	id <SVSiteItemViewControllerDelegate>   _delegate;

	SVWebEditorViewController *_webEditorViewController;
}

@property (retain) SVWebEditorViewController *webEditorViewController;
@property (retain) id <SVSiteItemViewControllerDelegate> delegate;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil webEditorViewController:(SVWebEditorViewController *)aWebEditorViewController;
@end
