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
    NSObjectController  *_inspectedPagesController;
}

@property(nonatomic, retain) NSObjectController *inspectedPagesController;

@end
