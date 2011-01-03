//
//  KTCollectionIndexFilenameButton.m
//  Marvel
//
//  Created by Mike on 24/01/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import "KTCollectionIndexFilenameButton.h"


@implementation KTCollectionIndexFilenameButton

#pragma mark -
#pragma mark Drawing

+ (NSImage *)gearIcon
{
	static NSImage *result;
	
	if (!result)
	{
		result = [[NSImage imageNamed:NSImageNameActionTemplate] retain];
		[result setSize:NSMakeSize(12.0, 12.0)];
	}
	
	return result;
}

- (void)drawRect:(NSRect)aRect
{
	float alpha = ([self isEnabled] ? 1.0 : 0.6);
	
	// Add in our gear icon
	NSImage *gearIcon = [[self class] gearIcon];
	[gearIcon drawAtPoint:NSMakePoint(5.0, 5.0) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:alpha];
	
	// Draw the popup arrow
	NSRect bounds = [self bounds];
	NSBezierPath *path = [NSBezierPath bezierPath];
	
	[path moveToPoint:NSMakePoint(NSMaxX(bounds) - 3.0, NSMaxY(bounds) - 14.0)];
	[path relativeLineToPoint:NSMakePoint(-3.5, 4.0)];
	[path relativeLineToPoint:NSMakePoint(-3.5, -4.0)];
	[path closePath];
	
	[[NSColor colorWithCalibratedWhite:0.25 alpha:alpha] setFill];
	[path fill];
}

@end
