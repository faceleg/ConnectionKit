//
//  KTDesignPickerBackground.m
//  Marvel
//
//  Created by Dan Wood on 7/22/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "KTDesignPickerBackground.h"


@implementation KTDesignPickerBackground

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)drawRect:(NSRect)rect
{
	static NSColor *sBGColorRegular = nil;
	static NSColor *sBGColorSearch = nil;
	
	if (nil == sBGColorRegular)
	{
		NSImage *designBG = [NSImage imageNamed:@"designBG"];
		NSImage *designBGSearch = [NSImage imageNamed:@"designBGSearch"];
		
		sBGColorRegular = [[NSColor colorWithPatternImage:designBG] retain];
		sBGColorSearch = [[NSColor colorWithPatternImage:designBGSearch] retain];
		
	}
	
	NSPoint windowOrigin = [self convertPoint:[self bounds].origin toView:nil];
	
	[[NSGraphicsContext currentContext] setPatternPhase:windowOrigin];
	[sBGColorRegular set];
	[NSBezierPath fillRect:rect];
	
}

@end
