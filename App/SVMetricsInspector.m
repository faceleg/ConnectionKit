//
//  SVMetricsInspector.m
//  Sandvox
//
//  Created by Mike on 29/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMetricsInspector.h"

#import "KTDocument.h"
#import "SVMediaGraphic.h"


@implementation SVMetricsInspector

- (IBAction)enterExternalURL:(id)sender;
{
    for (SVMediaGraphic *aGraphic in [self inspectedObjects])
    {
        if ([aGraphic media]) [aGraphic setMediaWithURL:nil];
    }
    
    NSWindow *window = [oURLField window];
    [window makeKeyWindow];
    [window makeFirstResponder:oURLField];
}

- (IBAction)chooseFile:(id)sender;
{
    KTDocument *document = [self representedObject];
    NSOpenPanel *panel = [document makeChooseDialog];
    
    if ([panel runModal] == NSFileHandlingPanelOKButton)
    {
        NSURL *URL = [panel URL];
        
        [[self inspectedObjects] makeObjectsPerformSelector:@selector(setMediaWithURL:)
                                                 withObject:URL];
    }
}

- (IBAction)makeOriginalSize:(NSButton *)sender;
{
    for (SVMediaGraphic *aGraphic in [self inspectedObjects])
    {
        [aGraphic makeOriginalSize];
    }
}

@end
