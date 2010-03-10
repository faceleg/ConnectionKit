//
//  KTLinkSourceView.m
//  Marvel
//
//  Created by Greg Hulands on 20/03/06.
//  Copyright 2006-2009 Karelia Software. All rights reserved.
//

#import "KTLinkSourceView.h"
#import "KTLinkConnector.h"


NSString *kKTLocalLinkPboardReturnType = @"kKTLocalLinkPboardReturnType";
NSString *kKTLocalLinkPboardAllowedType = @"kKTLocalLinkPboardAllowedType";


@implementation KTLinkSourceView


@synthesize collectionsOnly = _collectionsOnly;
@synthesize targetWindow = _targetWindow;
@synthesize connectedPage = _connectedPage;
@synthesize delegate = _delegate;



- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) 
	{
		_flags.begin = NO;
		_flags.end = NO;
		_flags.isConnecting = NO;
		_flags.isConnected = NO;
    }
    return self;
}

- (void) dealloc
{
	self.targetWindow = nil;
	self.connectedPage = nil;

	[super dealloc];
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

	if (!_flags.isConnecting)	// no shadow when we're connecting
	{
		NSShadow *aShadow = [[[NSShadow alloc] init] autorelease];
		[aShadow setShadowOffset:NSMakeSize(1,-3)];
		[aShadow setShadowBlurRadius:3.0];
		[aShadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.75]];
		[aShadow set];
	}
	[(_flags.isConnected ? sTargetSetImage : sTargetImage)
		drawInRect:centeredRect
		  fromRect:NSZeroRect
		 operation:NSCompositeSourceOver
		  fraction:_flags.isConnecting ? 0.5 : 1.0];		// Transparent while dragging
	[NSGraphicsContext restoreGraphicsState];
	
	if (_flags.isConnecting)	// while connecting, draw a rectangle around it
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
	_flags.isConnecting = YES;
	[self setNeedsDisplay:YES];
	NSCursor *targetCursor = [[NSCursor alloc] initWithImage:sTargetImage
											   hotSpot:NSMakePoint(8,8)];
	[targetCursor push];
	
	NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
	[pboard declareTypes:[NSArray arrayWithObject:kKTLocalLinkPboardAllowedType] owner:self];
	if (self.collectionsOnly)
	{
		[pboard setString:@"KTCollection" forType:kKTLocalLinkPboardAllowedType];	// target will reject drop if it's not a collection
	}
	else
	{
		[pboard setString:@"KTPage" forType:kKTLocalLinkPboardAllowedType];	// just put something else to indicate
	}
	
	NSRect bounds = [self bounds];
	NSPoint center = NSMakePoint(NSMidX(bounds), NSMidY(bounds));
	NSPoint p = [[self window] convertBaseToScreen:[self convertPoint:center toView:nil]];
	
	[[KTLinkConnector sharedConnector] startConnectionWithPoint:p pasteboard:pboard targetWindow:self.targetWindow];
	
	_flags.isConnecting = NO;
	[self setNeedsDisplay:YES];
	
	// Get the page from the pasteboard
	NSString *pageID = [pboard stringForType:kKTLocalLinkPboardReturnType];
	KTPage *targetPage = [KTPage pageWithUniqueID:pageID 
                           inManagedObjectContext:[[[self inspectedObjectsController] selection] managedObjectContext]];

	[targetCursor pop];
	[targetCursor release];

	self.connectedPage = targetPage;		// bindings could pick this up
	if (_flags.end)
	{
		[_delegate linkSourceConnectedTo:targetPage];
	}
	
}



- (void)setDelegate:(id <KTLinkSourceViewDelegate>)aDelegate;
{
	_flags.end = [aDelegate respondsToSelector:@selector(linkSourceConnectedTo:)] ? YES : NO;
	_delegate = aDelegate;
}


- (void)setConnected:(BOOL)isConnected;
{
	_flags.isConnected = isConnected;
	[self setNeedsDisplay:YES];
}
@end
