//
//  ContactElementFieldCell.m
//  ContactElement
//
//  Created by Mike on 17/05/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "ContactElementFieldCell.h"

#import <SandvoxPlugin.h>


@interface ContactElementFieldCell (Private)
- (NSTextFieldCell *)textFieldCell;
- (NSImageCell *)lockIconCell;
@end


@implementation ContactElementFieldCell

#pragma mark -
#pragma mark Memory Management

- (void)dealloc
{
	[myTextCell release];
	[myLockIconCell release];
	
	[super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
	ContactElementFieldCell *copy = [super copyWithZone:zone];
	
	[copy->myTextCell retain];
	[copy->myLockIconCell retain];
	
	return copy;
}

#pragma mark -
#pragma mark Accessors

- (NSString *)stringValue
{
	NSString *result = nil;
	
	NSString *identifier = [[self objectValue] identifier];
	
	if ([@"visitorName" isEqualToString:identifier]) {
		result = LocalizedStringInThisBundle(@"Name", "field label");
	}
	else if ([@"email" isEqualToString:identifier]) {
		result = LocalizedStringInThisBundle(@"Email", @"field label");
	}
	else if ([@"subject" isEqualToString:identifier]) {
		result = LocalizedStringInThisBundle(@"Subject", @"field label");
	}
	else if ([@"message" isEqualToString:identifier]) {
		result = LocalizedStringInThisBundle(@"Message", @"field label");
	}
	else if ([@"send" isEqualToString:identifier]) {
		result = LocalizedStringInThisBundle(@"Send", @"button label");
	}
	else {
		result = [[self objectValue] label];
	}
	
	if (!result || [result isEqualToString:@""]) {
		result = LocalizedStringInThisBundle(@"N/A", @"field label");
	}
	
	return result;
}

- (BOOL)shouldDrawLockIcon
{
	BOOL result = NO;
	
	NSString *identifier = [[self objectValue] identifier];
	if ([identifier isEqualToString:@"visitorName"] ||
		[identifier isEqualToString:@"email"] ||
		[identifier isEqualToString:@"subject"] ||
		[identifier isEqualToString:@"send"] ||
		[identifier isEqualToString:@"message"])
	{
		result = YES;
	}
	
	return result;
}

#pragma mark -
#pragma mark Drawing

- (NSTextFieldCell *)textFieldCell
{
	if (!myTextCell)
	{
		myTextCell = [[NSTextFieldCell alloc] initTextCell:@""];
		[myTextCell setAlignment:[self alignment]];
		[myTextCell setBezeled:NO];
		[myTextCell setBordered:NO];
		[myTextCell setEnabled:YES];
		[myTextCell setFont:[self font]];
		[myTextCell setLineBreakMode:[self lineBreakMode]];
		[myTextCell setWraps:[self wraps]];
	}
	
	return myTextCell;
}

- (NSImageCell *)lockIconCell
{
	if (!myLockIconCell)
	{
		NSImage *icon = [NSImage imageNamed:@"NSLockLockedTemplate"];	// try for Leopard resizable version
		if (nil == icon)
		{
			// fallback
			icon = [NSImage imageInBundle:[NSBundle bundleForClass:[self class]]
									named:@"lock.png"];
		}
	
		myLockIconCell = [[NSImageCell alloc] initImageCell:icon];
		[myLockIconCell setImageAlignment:NSImageAlignCenter];
		[myLockIconCell setImageScaling:NSScaleNone];
	}
	
	return myLockIconCell;
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	[[self textFieldCell] setStringValue:[self stringValue]];
	
	// How we draw depends on if there is a lock icon to draw
	if ([self shouldDrawLockIcon])
	{
		// Split the cell in two
		NSRect textRect;
		NSRect lockIconRect;
		NSDivideRect(cellFrame, &lockIconRect, &textRect, cellFrame.size.height, NSMaxXEdge);
		
		[[self textFieldCell] drawWithFrame:textRect inView:controlView];
		[[self lockIconCell] drawWithFrame:lockIconRect inView:controlView];
	}
	else
	{
		[[self textFieldCell] drawWithFrame:cellFrame inView:controlView];
	}
}

@end
