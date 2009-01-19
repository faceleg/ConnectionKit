//
//  KTBackgroundTabView.m
//  Marvel
//
//  Created by Dan Wood on 11/16/04.
//  Copyright 2004-2009 Karelia Software. All rights reserved.
//

/*
PURPOSE OF THIS CLASS/CATEGORY:
	Special version of TabView that displays a translucent background.  This allows us to have our setup assistant look like a typical Apple setup assistant, using a tabless NSTabView

TAXONOMY AND RELATIONSHIP TO OTHER CLASSES:
	Inherits NSTabView

IMPLEMENTATION NOTES & CAUTIONS:
	This ignores the draws-background attributes; it just does its own background drawing and lets the other drawing do what it wants.

TO DO:
	x

 */

#import "KTBackgroundTabView.h"

@implementation KTBackgroundTabView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self)
	{
        // default: translucent white background
		[self setBackgroundColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.7]];
		[self setBorderColor	:[NSColor colorWithCalibratedWhite:0.3 alpha:1.0]];
	}
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder
{
	if (self = [super initWithCoder:decoder])
	{
        // default: translucent white background
		[self setBackgroundColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.7]];
		[self setBorderColor	:[NSColor colorWithCalibratedWhite:0.3 alpha:1.0]];
	}
	return self;
}

- (void)dealloc
{
    [self setBackgroundColor: nil];
    [self setBorderColor: nil];
    [super dealloc];
}

- (void)drawRect:(NSRect)aRect
{
	// Draw background color
	[myBackgroundColor set];
	[NSBezierPath fillRect:aRect];

	// Draw border on the bounds (which will clip if that's all we want)
	[myBorderColor set];
	[NSBezierPath strokeRect:[self bounds]];

	[super drawRect:aRect];
}


- (NSColor *)backgroundColor
{
    return myBackgroundColor;
}
- (void)setBackgroundColor:(NSColor *)aBackgroundColor
{
    [aBackgroundColor retain];
    [myBackgroundColor release];
    myBackgroundColor = aBackgroundColor;
}

- (NSColor *)borderColor
{
    return myBorderColor;
}
- (void)setBorderColor:(NSColor *)aBorderColor
{
    [aBorderColor retain];
    [myBorderColor release];
    myBorderColor = aBorderColor;
}


@end
