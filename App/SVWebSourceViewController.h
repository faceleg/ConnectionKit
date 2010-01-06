//
//  SVWebSourceViewController.h
//  Sandvox
//
//  Created by Dan Wood on 1/5/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SVWebEditorViewController;

@interface SVWebSourceViewController : NSViewController {

	IBOutlet NSTextView *oSourceView;
	
	SVWebEditorViewController *_webEditorViewController;
}

@property (retain) SVWebEditorViewController *webEditorViewController;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil webEditorViewController:(SVWebEditorViewController *)aWebEditorViewController;
@end
