//
//  SVMetricsInspector.h
//  Sandvox
//
//  Created by Mike on 29/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "KSInspectorViewController.h"


@class KSURLInfoField;


@interface SVMetricsInspector : KSInspectorViewController
{
    IBOutlet KSURLInfoField *oFileInfoField;
}

- (IBAction)chooseFile:(NSButton *)sender;

@end
