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

// If your controller is not ready yet, return NO. Call -setSelectedViewController:self on the Web Content Area Controller when done
- (BOOL)viewShouldAppear:(BOOL)animated
webContentAreaController:(SVWebContentAreaController *)controller;

@end