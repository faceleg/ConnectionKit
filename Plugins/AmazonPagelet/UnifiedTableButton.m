#import "UnifiedTableButton.h"


@implementation UnifiedTableButton

- (void)awakeFromNib
{
	// This ensures our alternate image is draw when the button is clicked
	[[self cell] setHighlightsBy: NSContentsCellMask];
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
									   modifierFlags: nil
										   timestamp: nil
										windowNumber: [[self window] windowNumber]
											 context: nil
										 eventNumber: nil
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

# pragma mark *** Drawing ***

- (void)drawRect:(NSRect)aRect
{
	// Draw the right-hand border
	NSColor *borderColor = [NSColor lightGrayColor];
	
	[borderColor set];
	
	NSRect buttonFrame = NSInsetRect([self bounds], 0.0, 1.0);
	
	NSRect borderRect = NSMakeRect(NSMaxX(buttonFrame) - 1.0,
								   buttonFrame.origin.y,
								   1.0,
								   buttonFrame.size.height - 1.0);
	
	NSRectFill(borderRect);
	
	// Draw the rest of the button
	[super drawRect: aRect];
}

@end
