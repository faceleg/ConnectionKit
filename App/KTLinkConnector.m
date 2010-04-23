//
//  KTLinkConnector.m
//  Marvel
//
//  Created by Greg Hulands on 19/03/06.
//  Copyright 2006-2009 Karelia Software. All rights reserved.
//

#import "KTLinkConnector.h"

#import "KTDocument.h"

#import "Debug.h"

NSRect KTRectFromPoints(NSPoint point1, NSPoint point2);

const float kConnectorWidth = 4.0;

typedef enum {
	KTLinkConnectorLeftTopStyle = 0, 
	KTLinkConnectorLeftBottomStyle,
	KTLinkConnectorRightTopStyle,
	KTLinkConnectorRightBottomStyle
} KTLinkConnectorStyle;


@interface KTLinkConnectorView : NSView
{
	KTLinkConnectorStyle _style;
}

- (void)setStyle:(KTLinkConnectorStyle)style;

@end


NSRect KTRectFromPoints(NSPoint point1, NSPoint point2) {
    return NSMakeRect(((point1.x <= point2.x) ? point1.x : point2.x), ((point1.y <= point2.y) ? point1.y : point2.y), ((point1.x <= point2.x) ? point2.x - point1.x : point1.x - point2.x), ((point1.y <= point2.y) ? point2.y - point1.y : point1.y - point2.y));
}


#pragma mark -


@interface KTLinkConnector ()
- (NSDate *)startTime;
- (void)setStartTime:(NSDate *)aStartTime;
@end


#pragma mark -


@implementation KTLinkConnector

+ (id)sharedConnector
{
	static KTLinkConnector *_sharedConnector = nil;
    if (!_sharedConnector)
		_sharedConnector = [[KTLinkConnector alloc] init];
	return _sharedConnector;
}

- (id)init
{
	if (self = [super initWithContentRect:NSMakeRect(0,0,1,1)
								styleMask:NSBorderlessWindowMask
								  backing:NSBackingStoreBuffered
									defer:NO])
	{
		[self setBackgroundColor:[NSColor clearColor]];
		[self setOpaque:NO];
		[self setAlphaValue:1.0];
		[self setHasShadow:NO];
		[self setLevel:NSPopUpMenuWindowLevel];
		[self setIgnoresMouseEvents:YES];
		
		KTLinkConnectorView *view = [[KTLinkConnectorView alloc] initWithFrame:NSMakeRect(0,0,1,1)];
		[view setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
		[self setContentView:view];
		[view release];
	}
	return self;
}

- (void)dealloc
{
	// Don't worry about leaking, this is a singleton
	[super dealloc];
}

#pragma mark Overrides

- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)becomeFirstResponder { return YES; }
- (BOOL)resignFirstResponder { return YES; }
- (BOOL)ignoresMouseEvents { return YES; }

#pragma mark Methods

- (void)startConnectionWithPoint:(NSPoint)point pasteboard:(NSPasteboard *)pasteboard targetWindow:(NSWindow *)aWindow
{
	pboard = [pasteboard retain];
	NSEvent *theEvent;
	NSPoint curPoint;
	NSRect connectorRect;
	NSView *overView;
	
	[self setStartTime:[NSDate date]];
	lastViewOver = nil;
	[self setFrame:NSZeroRect display:NO];
	[self orderFront:self];
	[NSEvent startPeriodicEventsAfterDelay:0.3 withPeriod:0.05];
	
	while (1)
	{
		theEvent = [[NSApplication sharedApplication] nextEventMatchingMask:NSMouseMovedMask | NSLeftMouseUpMask
																  untilDate:[NSDate distantPast]
																	 inMode:NSEventTrackingRunLoopMode
																	dequeue:NO];
		curPoint = [NSEvent mouseLocation];
		
		NSEnumerator *winEnum = [[[NSApplication sharedApplication] windows] objectEnumerator];
		NSWindow *curWindow;
		NSView *contentView;
		NSPoint pointInWindow;
		overView = nil;
		
		while (curWindow = [winEnum nextObject])
		{
			if (aWindow && (curWindow != aWindow))
			{
				continue; // if target window specified, disallow test if to another window
			}
			contentView = [curWindow contentView];
			pointInWindow = [contentView convertPoint:[curWindow convertScreenToBase:curPoint] fromView:nil];
			overView = [contentView hitTest:pointInWindow];
			if (overView)
			{
				lastPoint = pointInWindow;
				break;
			}
		}
		
		if (overView)
		{
			if (![overView respondsToSelector:@selector(draggingEntered:)])
			{
				continue;
			}
		
			if (lastViewOver == nil)
			{
				//begin the drag operation call
				(void) [overView draggingEntered:self];
			}
			if (lastViewOver != overView && lastViewOver != nil)
			{
				// dragging exited
				if ([lastViewOver respondsToSelector:@selector(draggingExited:)])
				{
					[lastViewOver draggingExited:self];
				}
			}
			
			if ([overView respondsToSelector:@selector(draggingUpdated:)])
			{
				[overView draggingUpdated:self];
			}
		}
		else	// not over a view, so act as if we exited that view
		{
			if (nil != lastViewOver && [lastViewOver respondsToSelector:@selector(draggingExited:)])
			{
				[lastViewOver draggingExited:self];
			}
		}
		lastViewOver = overView;
		
		connectorRect = KTRectFromPoints(point, curPoint);
		connectorRect.origin.y = floor(connectorRect.origin.y) + 0.5;
		connectorRect.origin.x = floor(connectorRect.origin.x) + 0.5;
		connectorRect.size.width = floor(connectorRect.size.width) + 0.5;
		connectorRect.size.height = floor(connectorRect.size.height) + 0.5;
		
		if (NSWidth(connectorRect) < kConnectorWidth)
		{
			connectorRect.size.width = kConnectorWidth;
		}
		
		if (NSHeight(connectorRect) < kConnectorWidth)
		{
			connectorRect.size.height = kConnectorWidth;
		}
		
		KTLinkConnectorStyle style;
		
		if (curPoint.x > point.x)
		{
			if (curPoint.y > point.y)
			{
				style = KTLinkConnectorRightBottomStyle;
			}
			else
			{
				style = KTLinkConnectorRightTopStyle;
			}
		}
		else
		{
			if (curPoint.y > point.y)
			{
				style = KTLinkConnectorLeftBottomStyle;
			}
			else
			{
				style = KTLinkConnectorLeftTopStyle;
			}
		}
		[(KTLinkConnectorView *)[self contentView] setStyle:style];
		[[self contentView] setNeedsDisplay:YES];
		[self setFrame:connectorRect display:YES];
		
		if ([theEvent type] == NSLeftMouseUp)
		{
			if (overView)
			{
				// we dropped on the destination
				if ([overView respondsToSelector:@selector(prepareForDragOperation:)])
				{
					if ([overView performDragOperation:self])
					{
						if ([overView respondsToSelector:@selector(performDragOperation:)])
						{
							if ([overView performDragOperation:self])
							{
								if ([overView respondsToSelector:@selector(concludeDragOperation:)])
								{
									[overView concludeDragOperation:self];
								}
							}
						}
					}
				}
			}
			//connection complete
			break;
		}
	}
	[NSEvent stopPeriodicEvents];
	[pboard autorelease];
	[self endConnection];
}

- (void)showConnectionWithFrame:(NSRect)frame
{
	[(KTLinkConnectorView *)[self contentView] setStyle:KTLinkConnectorRightBottomStyle];
	[self setFrame:frame display:YES];
	
	NSEvent *theEvent;
	
	while (1)
	{
		theEvent = [[NSApplication sharedApplication] nextEventMatchingMask:NSLeftMouseDownMask
																  untilDate:[NSDate distantPast]
																	 inMode:NSEventTrackingRunLoopMode
																	dequeue:NO];
		if ([theEvent type] == NSLeftMouseDown)
		{
			break;
		}
	}
	[self endConnection];
}

- (void)endConnection
{
	[self orderOut:self];
}

#pragma mark NSDraggingInfo

- (NSDragOperation)_lastDragDestinationOperation
{
	return NSDragOperationMove;
}

- (NSWindow *)draggingDestinationWindow
{
	return [lastViewOver window];
}

- (NSDragOperation)draggingSourceOperationMask
{
	return NSDragOperationMove;
}

- (NSPoint)draggingLocation
{
	return lastPoint;
}

- (NSPoint)draggedImageLocation
{
	return lastPoint;
}

- (NSImage *)draggedImage
{
	return nil;
}

- (NSPasteboard *)draggingPasteboard
{
	return pboard;
}

- (id)draggingSource
{
	return self;
}

- (int)draggingSequenceNumber
{
	return 0;
}

- (void)slideDraggedImageTo:(NSPoint)screenPoint
{
	//do nothing
}

- (NSArray *)namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination
{
	return nil;
}

#pragma mark Accessors



- (NSDate *)startTime
{
    return myStartTime; 
}

- (void)setStartTime:(NSDate *)aStartTime
{
    [aStartTime retain];
    [myStartTime release];
    myStartTime = aStartTime;
}


@end

#pragma mark -

@implementation KTLinkConnectorView

- (id)initWithFrame:(NSRect)frame
{
	if (self = [super initWithFrame:frame])
	{
		_style = KTLinkConnectorRightTopStyle;
	}
	return self;
}

- (void)drawRect:(NSRect)rect
{
	[[NSColor clearColor] set];
	NSRectFill(rect);
	NSBezierPath *path = [NSBezierPath bezierPath];
	rect = NSInsetRect(rect,4,4);
	
	float w = NSWidth(rect);
	float h = NSHeight(rect);
	
	if (w > (7.0 * h))
	{
		w = 7.0 * h;	// don't let W get too large if H is small, it looks weird with a short rectangle to have a major S.
	}
	
	// periodicity.  At N pixels, we're repeating pattern.  Make them big so it's not too squiggly
	const int pw = 400;
	const int ph = 300;
	
	// Adjustment: w/ph -> 1 as w -> 100, then multiply by 2pi so that w=100 is 2pi.
	// multiply by the original value so we get a value between w and -w
	float mW = sin(w / pw * M_PI * 2);
	float mH = sin(h / ph * M_PI * 2);
	
	// Time based -- every N seconds periodicity.  Multiply together and you get non-cyclical looking behavior
	float mT1 = sin([[[KTLinkConnector sharedConnector] startTime] timeIntervalSinceNow] / 7.0 * M_PI * 2);
	float mT2 = sin([[[KTLinkConnector sharedConnector] startTime] timeIntervalSinceNow] / 13.0 * M_PI * 2);
	float mT3 = sin([[[KTLinkConnector sharedConnector] startTime] timeIntervalSinceNow] / 9.0 * M_PI * 2);

	// adjust widths by taking the 2/3rds point, then adding +/- 1/3 w, so we oscillate up to w and down to 1/3 w, plus a little bit of height's input too.  (Can go above)
	float w1 = w * ( (2.0/3.0) + (mW / 4.0) + (mH / 6.0) + (mT1 * mT2 / 10.0) );
	
	// Other width point: use mostly the HEIGHT to adjust the width, with a little bit of influence from width
	float w2 = w * ( (2.0/3.0) + (mH / 4.0) + (mW / 6.0) + (mT2 * mT3 / 10.0) );
	
	switch (_style)
	{
		case KTLinkConnectorLeftTopStyle:
		{
			[path moveToPoint:NSMakePoint(NSMinX(rect), NSMinY(rect))];
			[path curveToPoint:NSMakePoint(NSMaxX(rect), NSMaxY(rect))
				 controlPoint1:NSMakePoint(NSMinX(rect)+w2, NSMinY(rect))
				 controlPoint2:NSMakePoint(NSMaxX(rect)-w1, NSMaxY(rect))];
		} break;
		case KTLinkConnectorLeftBottomStyle:
		{
			[path moveToPoint:NSMakePoint(NSMinX(rect), NSMaxY(rect))];
			[path curveToPoint:NSMakePoint(NSMaxX(rect), NSMinY(rect))
				 controlPoint1:NSMakePoint(NSMinX(rect)+w2, NSMaxY(rect))
				 controlPoint2:NSMakePoint(NSMaxX(rect)-w1, NSMinY(rect))];
		} break;
		case KTLinkConnectorRightTopStyle:
		{
			[path moveToPoint:NSMakePoint(NSMaxX(rect), NSMinY(rect))];
			[path curveToPoint:NSMakePoint(NSMinX(rect), NSMaxY(rect))
				 controlPoint1:NSMakePoint(NSMaxX(rect)-w1, NSMinY(rect))
				 controlPoint2:NSMakePoint(NSMinX(rect)+w2, NSMaxY(rect))];
		} break;
		case KTLinkConnectorRightBottomStyle:
		{
			[path moveToPoint:NSMakePoint(NSMaxX(rect), NSMaxY(rect))];
			[path curveToPoint:NSMakePoint(NSMinX(rect), NSMinY(rect))
				 controlPoint1:NSMakePoint(NSMaxX(rect)-w1, NSMaxY(rect))
				 controlPoint2:NSMakePoint(NSMinX(rect)+w2, NSMinY(rect))];
		} break;
	}
	
	NSColor *color = [NSColor selectedControlColor];
	
	int inner = 1;
	int middle = 3;
	int outer = 7;
	
	[[color colorWithAlphaComponent:0.2] set];
	[path setLineWidth:outer];
	[path stroke];
	
	[[color colorWithAlphaComponent:0.3] set];
	[path setLineWidth:middle];
	[path stroke];

	[[color colorWithAlphaComponent:0.75] set];
	[path setLineWidth:inner];
	[path stroke];
	
}

- (void)setStyle:(KTLinkConnectorStyle)style
{
	_style = style;
}

#pragma mark -
#pragma mark Overrides

- (BOOL)isOpaque { return YES; }


@end
