//
//  KTTextField.m
//  Marvel
//
//  Created by Dan Wood on 5/24/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//
// Based on RSBrowserTextField courtesy of Brent Simmons of Ranchero Software

#import "KTTextField.h"
#import "KTTextFieldCell.h"
#import <Sandvox.h>

@implementation KTTextField
 
- (void) commonInit
{
	
	KTTextFieldCell *cell = [[[KTTextFieldCell alloc] init] autorelease];
	[self setCell: cell];
	[self setDrawsBackground:NO];
	[[self cell] setDrawsBackground:NO];
	[[self cell] setBordered: NO];
	[[self cell] setBezeled: NO]; 
	[[self cell] setEditable: YES]; 
	[[self cell] setScrollable: YES]; 
	[[self cell] setWraps: NO];
	[[self cell] setFont: [NSFont systemFontOfSize: 11.0]];
	[self setStringValue: @""];
	if ([[self cell] respondsToSelector: @selector (setFocusRingType:)])
	{
		[[self cell] setFocusRingType: NSFocusRingTypeNone];
	}
}
	
	
- (id) initWithFrame: (NSRect) frame
{
	
	self = [super initWithFrame: frame];	
	if (self)	[self commonInit];
	return (self);
}
	
	
- (id) initWithCoder: (NSCoder *) coder
{
	
	self = [super initWithCoder: coder];	
	if (self)	[self commonInit];
	return (self);
}

#pragma mark Drawing

- (void)drawRect:(NSRect)r
{
	[[NSColor whiteColor] set];
	NSRectFill (r);
	[super drawRect:r];
}
	











@end
