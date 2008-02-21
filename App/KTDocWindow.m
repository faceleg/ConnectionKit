//
//  KTDocWindow.m
//  Marvel
//
//  Created by Dan Wood on 10/11/04.
//  Copyright 2004 Biophony, LLC. All rights reserved.
//

/*
 PURPOSE OF THIS CLASS/CATEGORY:
	Capture click in the WebView and send it as a message to the WebView, so we can detect clicks.

TAXONOMY AND RELATIONSHIP TO OTHER CLASSES:
	Subclass NSWindow.  Works with KTWebView

IMPLEMENTATION NOTES & CAUTIONS:
	x

TO DO:
	x

 */

#import "KTDocWindow.h"

#import "Debug.h"
#import "KTDocWindowController.h"
#import "KTDocument.h"
#import "KTWebView.h"

/*
 
#import <Foundation/NSDebug.h>
#import <objc/objc.h>

// FIGURE OUT BACKTRACE --
// BASED ON CODE HERE: http://lists.gnu.org/archive/html/discuss-gnustep/2004-01/msg00396.html

// may be compiler and arch dependant
#define FRAME_RETURN_OFFSET      4
#define FRAME_ARG_OFFSET         8

#define FRAME_RETURN_ADDRESS(fp) \
(*(void**)((char *)(fp) + FRAME_RETURN_OFFSET))

#define FRAME_ARG_START(fp) \
((void*)((char *)(fp) + FRAME_ARG_OFFSET))

#define marg_get_ref(mArgs, anOffset, aType) \
( (aType *)((char *) mArgs + anOffset) )

#define marg_get_value(mArgs, anOffset, aType) \
( *marg_get_ref(mArgs, anOffset, aType) )

#define MAX_FRAMES               10 // # of frames to dump
#define FRAME_NEXT_OFFSET        0  // depending on arch/compiler

#define _cmdOffset 0		// wild-assed guess

#define NEXT_FRAME(fp) \
(*(void**)((char *)(fp) + FRAME_NEXT_OFFSET))

void dumpBacktrace(unsigned int startFrameNumber)
{
    unsigned int *returnAddress = 0, *framePointer;
    unsigned int *argStart, frameCount;
    SEL          sel;
	
    framePointer = NSFrameAddress(startFrameNumber);
    if( NULL == framePointer ) return;
    returnAddress = FRAME_RETURN_ADDRESS(framePointer);
	
    while( frameCount < MAX_FRAMES
		   && (framePointer = NEXT_FRAME(framePointer)) )
	{
		argStart = FRAME_ARG_START(framePointer);
		
		sel = marg_getValue(argStart, _cmdOffset, SEL);
		
		if( sel && sel_is_mapped(sel) )
		{
			// sel is valid, ie. a method not a function
			NSLog(@"%@", NSStringFromSelector(sel));		
		}
		else
		{
			return;
		}
		++frameCount;
		returnAddress = FRAME_RETURN_ADDRESS(framePointer);
	}
}

*/


@interface NSWindow ( PrivateHack )
- (void)_setFrameNeedsDisplay:(BOOL)fp8;
@end


@implementation KTDocWindow

- (void)close
{
	[oWebKitView removeFromSuperview];
	oWebKitView = nil;
	[super close];
}

- (id)initWithContentRect:(NSRect)contentRect
				styleMask:(unsigned int)styleMask
				  backing:(NSBackingStoreType)backingType
					defer:(BOOL)flag
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	BOOL useTextured = [defaults boolForKey:@"UseTexturedDocumentWindows"];
	BOOL useUnified = [defaults boolForKey:@"UseUnifiedToolbarWindows"];

	unsigned int newMask = styleMask
		| (useTextured? NSTexturedBackgroundWindowMask : 0)
		| (useUnified ? NSUnifiedTitleAndToolbarWindowMask : 0);
	return [super initWithContentRect:contentRect
							styleMask:newMask
							  backing:backingType
								defer:flag];
}

// Private override, this is hit downstream from NSapplication sendEvent in Tiger when you change the key window.
- (void)_setFrameNeedsDisplay:(BOOL)fp8;
{
	if ( [[self windowController] publishingMode] != kGeneratingPreview )
	{
		OFF((@"_setFrameNeedsDisplay ignored"));
		return;
	}
	[super _setFrameNeedsDisplay:fp8];
}

- (void)sendEvent:(NSEvent *)anEvent
{
	if ( [[self windowController] publishingMode] != kGeneratingPreview )
	{
		OFF((@"ignoring event:%@", anEvent));
		return;
	}

	NSEventType type = [anEvent type];
	if (type == NSLeftMouseDown)
	{
		NSPoint mouseLoc = [oWebKitView convertPoint:[anEvent locationInWindow] fromView:nil];
		// Convert from coordinates of the window (from the event) to that of the web kit view

		if (NSPointInRect(mouseLoc, [oWebKitView bounds]))
		{
			if ([anEvent clickCount] == 1)
			{
				BOOL cont = [((KTWebView *)oWebKitView) earlySingleClickAtCoordinates:mouseLoc modifierFlags:[anEvent modifierFlags]];
				if (cont)
				{
					// let webview handle it
					[super sendEvent:anEvent];
					// now we get a chance to process
					[((KTWebView *)oWebKitView) singleClickAtCoordinates:mouseLoc modifierFlags:[anEvent modifierFlags]];
				}
			}
			else if ([anEvent clickCount] == 2)
			{
				BOOL cont = [((KTWebView *)oWebKitView) earlyDoubleClickAtCoordinates:mouseLoc modifierFlags:[anEvent modifierFlags]];
				if (cont)
				{
					// let webview handle it
					[super sendEvent:anEvent];
					// now we get a chance to process
					[((KTWebView *)oWebKitView) doubleClickAtCoordinates:mouseLoc modifierFlags:[anEvent modifierFlags]];
				}
			}
			else	// triple click or whatever .. just let it be processed normally
			{
				// let webview handle it
				[super sendEvent:anEvent];
			}
		}
		else	// not in webview; just dispatch normally
		{
			[super sendEvent:anEvent];
		}
	}
	else	// not a mouse down, dispatch normally
	{
		[super sendEvent:anEvent];
	}
}

- (void)setWindowController:(NSWindowController *)windowController
{
	[super setWindowController:windowController];
	if ( [windowController isKindOfClass:[KTDocWindowController class]] )
	{
		[windowController setShouldCloseDocument:YES];
	}
}

- (void)document:(KTDocument *)doc shouldClose:(BOOL)shouldClose contextInfo:(void *)contextInfo
{
	if ( !shouldClose )
	{
		[doc setClosing:NO];
	}
}

@end
