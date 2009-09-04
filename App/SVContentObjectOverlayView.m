//
//  SVContentObjectOverlay.m
//  Sandvox
//
//  Created by Mike on 04/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVContentObjectOverlayView.h"


@implementation SVContentObjectOverlayView

- (id)XinitWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)XdrawRect:(NSRect)dirtyRect {
    // Drawing code here.
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)mouseDown:(NSEvent *)theEvent
{
    // Swallow mouse down events to stop them reaching the webview
}

@end
