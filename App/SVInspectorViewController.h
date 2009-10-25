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
  @private  // TODO: Enough spare ivars for later changes without breaking plug-ins
    NSArray             *_inspectedPages;
    NSArrayController   *_inspectedPagesController;
}

@property(nonatomic, copy, readonly) NSArray *inspectedPages;
@property(nonatomic, retain) NSArrayController *inspectedPagesController;

@end
