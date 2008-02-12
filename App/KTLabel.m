//
//  KTLabel.m
//  Marvel
//
//  Created by Dan Wood on 6/27/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTLabel.h"

// Like NSTextField, but heeds the enabled state

@implementation KTLabel

- (void)drawRect:(NSRect)aRect
{
	if ([self isEnabled])
	{
		[self setTextColor:[NSColor blackColor]];
	}
	else
	{
		[self setTextColor:[NSColor disabledControlTextColor]];
	}
	
	[super drawRect:aRect];
}


@end
