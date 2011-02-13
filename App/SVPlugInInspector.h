//
//  SVPlugInInspector.h
//  Sandvox
//
//  Created by Mike on 30/12/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "KSInspectorViewController.h"

#import "SVGraphic.h"


@class SVInspectorViewController;


@interface SVPlugInInspector : KSInspectorViewController
{
  @private
    NSArray                     *_inspectedPages;
    SVInspectorViewController   *_selectedInspector;
    NSMutableDictionary         *_plugInInspectors;
}

@property(nonatomic, copy) NSArray *inspectedPages;
@property(nonatomic, retain) SVInspectorViewController *selectedInspector;

@end
