//
//  UnifiedTableButton2.m
//  KTPlugins
//
//  Created by Mike on 10/05/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "UnifiedTableButton.h"
#import "UnifiedTableButtonCell.h"


@implementation UnifiedTableButton

#pragma mark -
#pragma mark Init

- (id)initWithCoder:(NSCoder *)decoder
{
	NSKeyedUnarchiver *unarchiver = nil;		// to stop initialization warning; we use it twice below.
	Class oldCellClass = nil;		// to stop initialization warning; we use it twice below.
	
	if ([decoder allowsKeyedCoding])
	{
		unarchiver = (NSKeyedUnarchiver *)decoder;
		oldCellClass = [unarchiver classForClassName: @"NSButtonCell"];
		
		[unarchiver setClass: [UnifiedTableButtonCell class] forClassName: @"NSButtonCell"];
	}
	
	[super initWithCoder: decoder];
	
	if (unarchiver) {
		[unarchiver setClass:oldCellClass forClassName:@"NSButtonCell"];
	}
	
	return self;
}

# pragma mark *** Menu ***

- (void)openMenu
{
	// Don't do anything if there is no menu
	NSMenu *menu = [self menu];
	if (!menu) {
		return;
	}
	
	
	[self highlight: YES];	// Highlight whilst the menu is open
	
	
	// Build the event for the menu
	NSRect frame = [self frame];
	NSPoint ourMenuPoint = NSMakePoint(NSMinX(frame), NSMinY(frame));
	NSPoint windowMenuPoint = [[self superview] convertPoint: ourMenuPoint toView: nil];
	
	NSEvent *menuEvent = [NSEvent mouseEventWithType: NSLeftMouseDown
											location: windowMenuPoint
									   modifierFlags: 0
										   timestamp: 0
										windowNumber: [[self window] windowNumber]
											 context: nil
										 eventNumber: 0
										  clickCount: 1
										    pressure: 1];
	
	// Display the menu
	NSFont *font = [NSFont menuFontOfSize: [NSFont systemFontSizeForControlSize: NSSmallControlSize]];
	
	[NSMenu popUpContextMenu: menu
				   withEvent: menuEvent
					 forView: self
					withFont: font];
	
	// Once finished de-highlight the button
	[self highlight: NO];
}


// Stop the usual, full size contextual menu appearing
- (NSMenu *)menuForEvent:(NSEvent *)theEvent { return nil; }


// Open the menu if we have one
- (void)mouseDown:(NSEvent *)theEvent
{
	if ([self menu]) {
		[self openMenu];
	}
	else {
		[super mouseDown: theEvent];
	}
}


// Open the menu upon a keyboard command
- (BOOL)sendAction:(SEL)theAction to:(id)theTarget
{
	BOOL result = YES;
	
	if ([self menu]) {
		[self openMenu];
	}
	else {
		result = [super sendAction: theAction to: theTarget];
	}
	
	return result;
}

@end
