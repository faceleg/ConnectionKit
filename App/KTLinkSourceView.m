//
//  KTLinkSourceView.m
//  Marvel
//
//  Created by Greg Hulands on 20/03/06.
//  Copyright 2006-2009 Karelia Software. All rights reserved.
//

#import "KTLinkSourceView.h"
#import "KTLinkConnector.h"


NSString *kKTLocalLinkPboardType = @"kKTLocalLinkPboardType";


@implementation KTLinkSourceView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) 
	{
		myFlags.begin = NO;
		myFlags.end = NO;
		myFlags.ui = NO;
		myFlags.isConnecting = NO;
		myFlags.isConnecting = NO;
    }
    return self;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
	return YES;
}


static NSImage *sTargetImage = nil;
static NSImage *sTargetSetImage = nil;

- (void)drawRect:(NSRect)rect 
{
    if (!sTargetImage)
	{
		sTargetImage = [[NSImage imageNamed:@"target"] retain];
		[sTargetImage setScalesWhenResized:YES];
		[sTargetImage setSize:NSMakeSize(16,16)];
		sTargetSetImage = [[NSImage imageNamed:@"target_set"] retain];
		[sTargetSetImage setScalesWhenResized:YES];
		[sTargetSetImage setSize:NSMakeSize(16,16)];
	}
	
	NSRect centeredRect = NSMakeRect(NSMidX(rect) - 8, NSMidY(rect) - 8, 16, 16);

	[NSGraphicsContext saveGraphicsState];

	if (!myFlags.isConnecting)	// no shadow when we're connecting
	{
		NSShadow *aShadow = [[[NSShadow alloc] init] autorelease];
		[aShadow setShadowOffset:NSMakeSize(1,-3)];
		[aShadow setShadowBlurRadius:3.0];
		[aShadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.75]];
		[aShadow set];
	}
	[(myFlags.isConnected ? sTargetSetImage : sTargetImage)
		drawInRect:centeredRect
		  fromRect:NSZeroRect
		 operation:NSCompositeSourceOver
		  fraction:myFlags.isConnecting ? 0.5 : 1.0];		// Transparent while dragging
	[NSGraphicsContext restoreGraphicsState];
	
	if (myFlags.isConnecting)	// while connecting, draw a rectangle around it
	{
		NSRect anOutline = NSInsetRect(centeredRect, -2, -2);
		
		NSBezierPath *path = [NSBezierPath bezierPathWithRect:anOutline];
		[path setLineWidth:1.0];
		[[NSColor knobColor] set];
		[path stroke];
	}
}

- (void)mouseDown:(NSEvent *)theEvent
{
	myFlags.isConnecting = YES;
	[self setNeedsDisplay:YES];
	NSPasteboard *pboard = nil;
	NSCursor *target = [[NSCursor alloc] initWithImage:sTargetImage
											   hotSpot:NSMakePoint(8,8)];
	[target push];
	
	if (myFlags.begin)
	{
		pboard = [delegate linkSourceDidBeginDrag:self];
	}
			
	NSRect bounds = [self bounds];
	NSPoint center = NSMakePoint(NSMidX(bounds), NSMidY(bounds));
	NSPoint p = [[self window] convertBaseToScreen:[self convertPoint:center toView:nil]];
	id ui = nil;
	if (myFlags.ui)
	{
		ui = [delegate userInfoForLinkSource:self];
	}
	
	[[KTLinkConnector sharedConnector] startConnectionWithPoint:p pasteboard:pboard userInfo:ui];
	
	myFlags.isConnecting = NO;
	[self setNeedsDisplay:YES];
	
	if (myFlags.end)
	{
		[delegate linkSourceDidEndDrag:self withPasteboard:pboard];
	}
	
	[target pop];
	[target release];
}



- (void)setDelegate:(id <KTLinkSourceViewDelegate>)aDelegate;
{
	myFlags.begin = [aDelegate respondsToSelector:@selector(linkSourceDidBeginDrag:)] ? YES : NO;
	myFlags.end = [aDelegate respondsToSelector:@selector(linkSourceDidEndDrag:withPasteboard:)] ? YES : NO;
	myFlags.ui = [aDelegate respondsToSelector:@selector(userInfoForLinkSource:)] ? YES : NO;
	delegate = aDelegate;
}

- (id <KTLinkSourceViewDelegate>)delegate;
{
	return delegate;
}

- (void)setConnected:(BOOL)isConnected;
{
	myFlags.isConnected = isConnected;
	[self setNeedsDisplay:YES];
}
@end
