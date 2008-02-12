//
//  HSAView.m
//  HostSetupAssistant
//
//  Created by Greg Hulands on 9/01/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "HSAView.h"


@implementation HSAView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self)
	{
		[self setBorderType:NSNoBorder];
		[self setTitlePosition:NSNoTitle];
		
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
		[self setBorderType:NSNoBorder];
		[self setTitlePosition:NSNoTitle];
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
