//
//  SVWebSourceViewController.h
//  Sandvox
//
//  Created by Dan Wood on 1/5/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVSiteItemViewController.h"

#import "SVWebContentAreaController.h"


@class SVWebEditorViewController;

@interface SVWebSourceViewController : NSViewController <SVSiteItemViewController> {

	IBOutlet NSTextView *oSourceView;

    KTWebViewViewType           _viewType;
    SVWebEditorViewController   *_webEditorViewController;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil webEditorViewController:(SVWebEditorViewController *)aWebEditorViewController;

@property(nonatomic) KTWebViewViewType viewType;
@property(nonatomic, retain) SVWebEditorViewController *webEditorViewController;

@end
