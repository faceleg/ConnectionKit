//
//  SVSiteItemViewController.h
//  Sandvox
//
//  Created by Mike on 15/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class SVWebContentAreaController;


@protocol SVSiteItemViewController

/*!
 *  Called by the Web Content Area Controller when:
 *  A)  The user changes view type
 *  B)  The selected pages change
 *
 *  So this is a good point to update your view to reflect the selection.
 *  If the view is not ready yet (perhaps it's an asynchronous update process), return NO. Then call -setSelectedViewController:self on controller when done.
 */
- (BOOL)viewShouldAppear:(BOOL)animated
webContentAreaController:(SVWebContentAreaController *)controller;

@end