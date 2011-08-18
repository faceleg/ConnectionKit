//
//  SVDocWindow.m
//  Sandvox
//
//  Created by Mike on 15/10/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVDocWindow.h"


@implementation SVDocWindow

@synthesize constrainingToScreenSuspended = _constrainingToScreenSuspended;

// This window has its usual -constrainFrameRect:toScreen: behavior temporarily suppressed.
// This enables our window's custom Full Screen Exit animations to avoid being constrained by the
// top edge of the screen and the menu bar.
//
- (NSRect)constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen *)screen
{
    if (_constrainingToScreenSuspended)
    {
        return frameRect;
    }
    else
    {
        return [super constrainFrameRect:frameRect toScreen:screen];
    }
}

- (void) dealloc
{
	NSArray *childWindows = [self childWindows];
	for (NSWindow *childWindow in childWindows)
	{
		[self removeChildWindow:childWindow];	// make sure child window isn't there if parent window is going away, case #105167 ?
	}
	
	[super dealloc];
}

- (BOOL)makeFirstResponder:(NSResponder *)responder
{
    BOOL result = [super makeFirstResponder:responder];
    
    if (result)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:SVDocWindowDidChangeFirstResponderNotification
                                                            object:self];
    }
    
    return result;
}

@end
