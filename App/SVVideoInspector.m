//
//  SVVideoInspector.m
//  Sandvox
//
//  Created by Dan Wood on 8/6/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVVideoInspector.h"
#import "KTDocument.h"
#import "SVVideo.h"

@implementation SVVideoInspector


- (IBAction)choosePosterFrame:(id)sender;
{
	KTDocument *document = [self representedObject];
    NSOpenPanel *panel = [document makeChooseDialog];
	[panel setAllowedFileTypes:[NSArray arrayWithObject:(NSString *)kUTTypeImage]];

    if ([panel runModal] == NSFileHandlingPanelOKButton)
    {
        NSURL *URL = [panel URL];
        
        id video = [[self inspectedObjectsController] selection];
        [video setPosterFrame:URL];
    }
}

@end
