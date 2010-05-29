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
    IBOutlet NSTextField    *oURLField;
}

- (IBAction)enterExternalURL:(id)sender;
- (IBAction)chooseFile:(id)sender;

- (IBAction)makeOriginalSize:(NSButton *)sender;

@end
