//
//  KTTextFieldCell.m
//  Marvel
//
//  Created by Dan Wood on 5/24/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//
// Based on RSBrowserAddressCell courtesy of Brent Simmons of Ranchero Software

#import "KTTextFieldCell.h"
#import <Sandvox.h>

@implementation KTTextFieldCell

- (NSFocusRingType)focusRingType
{
	return (NSFocusRingTypeNone);
}

- (NSRect) calculateFrame: (NSRect) r
{
	NSRect textFrame = NSInsetRect (r, 3, 3);
	return textFrame;
}

- (void) editWithFrame: (NSRect) aRect inView: (NSView *) controlView
				editor: (NSText *) textObj delegate: (id) anObject
				 event: (NSEvent *) theEvent
{

	NSRect textFrame = [self calculateFrame: aRect];
	
	[super editWithFrame: textFrame inView: controlView
				  editor: textObj delegate: anObject event: theEvent];
}

- (void) selectWithFrame: (NSRect) aRect inView: (NSView *) controlView
				  editor: (NSText *) textObj delegate: (id) anObject
				   start: (int) selStart length: (int) selLength
{

	NSRect textFrame = [self calculateFrame: aRect];

	[super selectWithFrame: textFrame inView: controlView
					editor: textObj delegate: anObject start: selStart length: selLength];
}

- (void) drawBorder: (NSRect) cellFrame
{

	[NSGraphicsContext saveGraphicsState];
	[[NSGraphicsContext currentContext] setShouldAntialias:NO];

	NSBezierPath *path = [NSBezierPath bezierPath];
	float x = cellFrame.origin.x;
	float y = cellFrame.origin.y;
	float width = cellFrame.size.width;
	float height = cellFrame.size.height;

	/*Top horizontal*/

	[path setLineWidth: 1.0];
	[path moveToPoint: NSMakePoint (x, y+1)];
	[path lineToPoint: NSMakePoint (x + width, y+1)];
	[[NSColor grayColor] set];
	[[NSColor colorWithCalibratedWhite:0.74 alpha:1.0] set];
	[path stroke];

	[[NSColor lightGrayColor] set];
	[[NSColor grayColor] set];
	[[NSColor colorWithCalibratedWhite:0.74 alpha:1.0] set];
	/*Left vertical*/
	[path moveToPoint: NSMakePoint (x, y + 1)];
	[path lineToPoint: NSMakePoint (x, y + height)];
	[path stroke];
	/*Right vertical*/
	[path moveToPoint: NSMakePoint ((x + width) - 1, y + 1)];
	[path lineToPoint: NSMakePoint ((x + width) - 1, y + height)];
	[path stroke];
	/*Bottom horizontal*/
	[path moveToPoint: NSMakePoint (x, y + height)];
	[path lineToPoint: NSMakePoint (x + width, y + height)];
	[path stroke];
	[NSGraphicsContext restoreGraphicsState];
}


- (void) drawWithFrame: (NSRect) cellFrame inView: (NSView *) controlView
{
	BOOL flShowsFirstResponder = [self showsFirstResponder];

	NSRect textFrame = [self calculateFrame: cellFrame];

	[self drawBorder: cellFrame];

	[self setShowsFirstResponder: NO];
	[super drawWithFrame: textFrame inView: controlView];
	[self setShowsFirstResponder: flShowsFirstResponder];
}

@end
