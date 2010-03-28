//
//  SVMetricsInspector.m
//  Sandvox
//
//  Created by Mike on 29/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMetricsInspector.h"

#import "KTDocument.h"


@implementation SVMetricsInspector

- (IBAction)chooseFile:(NSButton *)sender;
{
    KTDocument *document = [self representedObject];
    NSOpenPanel *panel = [document makeChooseDialog];
    
    if ([panel runModal] == NSFileHandlingPanelOKButton)
    {
        NSURL *URL = [panel URL];
        
        NSBeep();
    }
}

@end
