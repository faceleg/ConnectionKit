//
//  SVInspectorWindowController.h
//  Sandvox
//
//  Created by Mike on 22/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KSInspector.h"


@interface SVInspector : KSInspector
{
  @private
    NSArrayController   *_inspectedPagesController;
}

@property(nonatomic, retain, readonly) NSArrayController *inspectedPagesController;
- (void)setInspectedPages:(NSArray *)pages;

@end
