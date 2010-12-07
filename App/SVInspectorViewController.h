//
//  SVInspectorViewController.h
//  Sandvox
//
//  Created by Mike on 23/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//


#import <Cocoa/Cocoa.h>


@interface SVInspectorViewController : NSViewController
{
  @private
    NSArrayController   *_inspectedObjectsController;
    id                  _reserved2;
    id                  _reserved3;
    id                  _reserved4;
    id                  _reserved5;
    CGFloat             _tabHeight;
}

#pragma mark Inspected Objects

- (NSArray *)inspectedObjects;  // NOT KVO-compliant yet

// Bind to File's Owner inspectedObjectsController.selection.<key>
// Should have no reason to start introspecting or editing the controller's other properties; Plug-in system will do that for you.
- (NSArrayController *)inspectedObjectsController;


#pragma mark Presentation
// defaults to height of view during -setView:
@property(nonatomic) CGFloat contentHeightForViewInInspector;


@end