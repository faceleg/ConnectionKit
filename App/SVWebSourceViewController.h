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
	id <SVSiteItemViewControllerDelegate>   _delegate;  // weak ref

	SVWebEditorViewController *_webEditorViewController;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil webEditorViewController:(SVWebEditorViewController *)aWebEditorViewController;

@property(nonatomic, retain) SVWebEditorViewController *webEditorViewController;
@property(nonatomic, assign) id <SVSiteItemViewControllerDelegate> delegate;

@end
