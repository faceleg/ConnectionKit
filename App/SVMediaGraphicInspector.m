//
//  SVMediaGraphicInspector.m
//  Sandvox
//
//  Created by Mike on 10/08/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMediaGraphicInspector.h"

#import "KTDocument.h"

#import "NSBundle+Karelia.h"


@implementation SVMediaGraphicInspector

#pragma mark View

- (void)loadView;
{
    // Load File Info first
    [[NSBundle mainBundle] loadNibNamed:@"FileInfo" owner:self];
    NSView *fileInfoView = [self view];
    
    // Load proper view
    [super loadView];
    
    // Cobble the two together
    NSView *otherView = [self view];
    
    NSView *view = [[NSView alloc] initWithFrame:
                    NSMakeRect(0.0f,
                               0.0f,
                               230.0f,
                               [fileInfoView frame].size.height + [otherView frame].size.height)];
    
    [view setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    
    NSRect fileInfoFrame = [fileInfoView frame];
    NSRect otherViewFrame;
    NSDivideRect([view bounds],
                 &fileInfoFrame,
                 &otherViewFrame,
                 fileInfoFrame.size.height,
                 NSMaxYEdge);
    
    [fileInfoView setFrame:fileInfoFrame];
    [view addSubview:fileInfoView];
    
    [otherView setFrame:otherViewFrame];
    [view addSubview:otherView];
    
    [self setView:view];
    [view release];
}

- (IBAction)enterExternalURL:(id)sender;
{
    NSWindow *window = [oURLField window];
    [window makeKeyWindow];
    [oURLField setHidden:NO];
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

@end
