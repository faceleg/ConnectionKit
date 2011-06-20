//
//  KTPulsatingOverlay.m
//  Marvel
//
//  Created by Greg Hulands on 23/03/06.
//  Copyright 2006-2011 Karelia Software. All rights reserved.
//

#import "KTPulsatingOverlay.h"

@interface KTPulsatingView : NSView 
{
	
}

@end

static KTPulsatingOverlay *_sharedOverlay = nil;

@implementation KTPulsatingOverlay

+ (KTPulsatingOverlay *)sharedOverlay
{
	if (!_sharedOverlay)
	{
		_sharedOverlay = [[KTPulsatingOverlay alloc] init];
	}
	return _sharedOverlay;
}

- (id)init
{
	if (self = [super initWithContentRect:NSMakeRect(0,0,1,1)
								styleMask:NSBorderlessWindowMask
								  backing:NSBackingStoreBuffered
									defer:NO])
	{
		[self setBackgroundColor:[NSColor clearColor]];
		[self setAlphaValue:0.5];
		[self setHasShadow:NO];
		[self setLevel:NSStatusWindowLevel];

		myAlpha = 50;
		isFading = NO;
		KTPulsatingView *v = [[KTPulsatingView alloc] initWithFrame:NSMakeRect(0,0,1,1)];
		[v setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
		[self setContentView:v];
		[v release];
	}
	return self;
}

- (void)displayWithFrame:(NSRect)frame
{
	if (!myAnimateTimer)
	{
		myAnimateTimer = [[NSTimer scheduledTimerWithTimeInterval:0.1
														   target:self
														 selector:@selector(animate:)
														 userInfo:nil
														  repeats:YES] retain];
	}
	[self orderFront:self];
	[self setFrame:NSInsetRect(frame, -4,-4) display:YES];
}

- (void)hide
{
	[myAnimateTimer invalidate];
	[myAnimateTimer release];
	myAnimateTimer = nil;
	[self orderOut:self];
}

- (void)animate:(NSTimer *)timer
{
	if (isFading)
	{
		myAlpha -= 10;
	}
	else
	{
		myAlpha += 10;
	}
	
	if (myAlpha > 100)
	{
		myAlpha = 100;
		isFading = YES;
	}
	if (myAlpha < 40)
	{
		isFading = NO;
	}
	[self setAlphaValue:((myAlpha * 1.0) / 100.0)];
}

- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)becomeFirstResponder { return YES; }
- (BOOL)resignFirstResponder { return YES; }
- (BOOL)ignoresMouseEvents { return YES; }
- (BOOL)isOpaque { return NO; }

@end

@implementation KTPulsatingView

- (void)drawRect:(NSRect)r
{
	[[NSColor clearColor] set];
	NSRectFill(r);
		
	[[NSColor selectedControlColor] set];
	NSFrameRectWithWidthUsingOperation(r, 4.0, NSCompositeSourceOver);
}

- (BOOL)isOpaque { return YES; }

@end
