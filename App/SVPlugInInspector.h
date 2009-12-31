//
//  SVPlugInInspector.h
//  Sandvox
//
//  Created by Mike on 30/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVInspectorViewController.h"


@interface SVPlugInInspector : SVInspectorViewController
{
    SVInspectorViewController   *_selectedInspector;
}

@property(nonatomic, retain) SVInspectorViewController *selectedInspector;

@end
