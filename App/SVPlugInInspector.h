//
//  SVPlugInInspector.h
//  Sandvox
//
//  Created by Mike on 30/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KSInspectorViewController.h"


@class SVInspectorViewController;


@interface SVPlugInInspector : KSInspectorViewController
{
    SVInspectorViewController   *_selectedInspector;
}

@property(nonatomic, retain) SVInspectorViewController *selectedInspector;

@end
