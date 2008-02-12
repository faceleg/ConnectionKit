//
//  KTBorderlessWindow.m
//  KTComponents
//
//  Created by Terrence Talbot on 11/2/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTBorderlessWindow.h"

@interface NSObject ( KTBorderlessWindowDelegate )
- (void)windowDidEscape:(NSWindow *)aWindow;
@end


@implementation KTBorderlessWindow

- (id)initWithContentRect:(NSRect)contentRect 
				styleMask:(unsigned int)aStyle
				  backing:(NSBackingStoreType)bufferingType
					defer:(BOOL)flag
{
    NSWindow *window = [super initWithContentRect:contentRect 
										styleMask:NSBorderlessWindowMask 
										  backing:NSBackingStoreBuffered 
											defer:NO];
	
	 // to see through parts of window where we don't draw
    [window setBackgroundColor:[NSColor clearColor]];
    [window setOpaque:NO];
	
    [window setHasShadow:YES];
	
    return window;
}

- (BOOL)canBecomeKeyWindow
{
	// we have to specifically override and return YES in a borderless window
    return YES;
}

- (void)sendEvent:(NSEvent *)anEvent
{
    NSEventType type = [anEvent type];
    
    if ( type == NSKeyDown )
    {
        unsigned int keyCode = [anEvent keyCode];
        unsigned int kVirtualEscapeKey = 0x035; // from iGetKeys.h
        if ( keyCode == kVirtualEscapeKey )
        {
            id delegate = [self delegate];
            if ( [delegate respondsToSelector:@selector(windowDidEscape:)] )
            {
                [delegate windowDidEscape:self];
            }
        }
        else
        {
            [super sendEvent:anEvent];
        }
    }
    else
    {
        [super sendEvent:anEvent];
    }
}

@end
