//
//  SVInspectorViewController.h
//  Sandvox
//
//  Created by Mike on 23/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class KTDocument;


@interface SVInspectorViewController : NSViewController
{
  @private  // TODO: Enough spare ivars for later changes without breaking plug-ins
    KTDocument          *_inspectedDocument;
    NSArray             *_inspectedPages;
    NSArrayController   *_inspectedPagesController;
}

@property(nonatomic, retain) KTDocument *inspectedDocument;
@property(nonatomic, copy, readonly) NSArray *inspectedPages;
@property(nonatomic, retain) NSObjectController *inspectedPagesController;

@end
