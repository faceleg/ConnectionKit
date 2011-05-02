//
//  SVInspectorViewController.h
//  Sandvox
//
//  Created by Mike on 23/10/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

//  This header should be well commented as to its functionality. Further information can be found at 
//  http://docs.karelia.com/z/Sandvox_Developers_Guide.html


#import <Cocoa/Cocoa.h>


@interface SVInspectorViewController : NSViewController
{
  @private
    NSArrayController   *_inspectedObjectsController;
    NSArray             *_inspectedPages;
    id                  _reserved2;
    id                  _reserved3;
    id                  _reserved4;
    CGFloat             _tabHeight;
}

#pragma mark Inspected Objects

- (NSArray *)inspectedObjects;  // NOT KVO-compliant yet

// Bind to File's Owner inspectedObjectsController.selection.<key>
// Should have no reason to start introspecting or editing the controller's other properties; Plug-in system will do that for you.
- (NSArrayController *)inspectedObjectsController;

- (NSArray *)inspectedPages;    // KVO-compliant


#pragma mark Presentation
// defaults to height of view during -setView:
@property(nonatomic) CGFloat contentHeightForViewInInspector;


@end