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

- (void)loadView;
{
    [super loadView];
    
    // Target File Info's cancel button at us
    NSButtonCell *cancelButtonCell = [[oFileInfoField cell] cancelButtonCell];
    [cancelButtonCell setTarget:self];
    [cancelButtonCell setAction:@selector(deleteFile:)];
}

- (IBAction)chooseFile:(NSButton *)sender;
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

- (IBAction)deleteFile:(NSButtonCell *)sender;
{
    [[self inspectedObjects] makeObjectsPerformSelector:@selector(setMediaWithURL:)
                                             withObject:nil];
}

- (IBAction)makeOriginalSize:(NSButton *)sender;
{
    for (SVMediaGraphic *aGraphic in [self inspectedObjects])
    {
        [aGraphic makeOriginalSize];
    }
}

@end
