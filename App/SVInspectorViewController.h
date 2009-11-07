//
//  SVInspectorViewController.h
//  Sandvox
//
//  Created by Mike on 23/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "KSInspectorTabsController.h"


@class KTDocument;


@interface SVInspectorViewController : NSViewController <KSInspectorViewController>
{
  @private  // TODO: Enough spare ivars for later changes without breaking plug-ins
    NSImage *_icon;
    
    KTDocument          *_inspectedDocument;
    NSArrayController   *_inspectedObjectsController;
}

@property(nonatomic, retain) NSImage *icon;

@property(nonatomic, retain) KTDocument *inspectedDocument;

//  Both of these are KVO-compliant so you can bind to them
@property(nonatomic, copy, readonly) NSArray *inspectedObjects;
@property(nonatomic, retain) NSObjectController *inspectedObjectsController;

@end
