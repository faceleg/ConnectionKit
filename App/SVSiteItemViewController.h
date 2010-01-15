//
//  SVSiteItemViewController.h
//  Sandvox
//
//  Created by Mike on 15/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class SVSiteItem;
@protocol SVSiteItemViewControllerDelegate;


@protocol SVSiteItemViewController

// Owning view controller will try to avoid placing the receiver onscreen if this returns NO. MUST be KVO-compliant
@property(nonatomic, readonly) BOOL viewIsReadyToAppear;

- (void)loadSiteItem:(SVSiteItem *)item;
- (void)setDelegate:(id <SVSiteItemViewControllerDelegate>)delegate;

@end


#pragma mark -


@protocol SVSiteItemViewControllerDelegate

// The SVSiteItemViewController should call this upon its delegate if it's time to display the source view
- (void)siteItemViewControllerShowSourceView:(NSViewController <SVSiteItemViewController> *)sender;

@end