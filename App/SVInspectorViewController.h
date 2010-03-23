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
}

//  DON'T try to override any initializer instance methods; Plug-in system makes no guarantee about which it will use.


#pragma mark Inspected Objects

- (NSArray *)inspectedObjects;  // NOT KVO-compliant yet

// Bind to File's Owner inspectedObjectsController.selection.<key>
// Should have no reason to start introspecting or editing the controller's other properties; Plug-in system will do that for you.
- (NSArrayController *)inspectedObjectsController;

@end


@interface SVInspectorViewController (Documentation)

- (NSString *)nibName;      // you MUST override to locate the correct nib
- (NSBundle *)nibBundle;    // can override for custom bundle, but default should be fine


@end