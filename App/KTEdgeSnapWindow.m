//
// KTEdgeSnapWindow.m
// Marvel
//
// Created by Dan Wood on 10/20/06.
// Copyright 2006 Karelia Software. All rights reserved.
// Inspired by code from Matt Gemmel and Fire
//

#import "KTEdgeSnapWindow.h"
#include <unistd.h>


@implementation KTEdgeSnapWindow




#define kSnapFromBeyondEdge -32
#define kSnapFromNearEdge 20

#define kSleepMilliseconds 500

- (id)initWithContentRect:(NSRect)contentRect styleMask:(unsigned int)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
{
	self = [super initWithContentRect:contentRect styleMask:aStyle backing:bufferingType defer:flag];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowMoved:) name:NSWindowDidMoveNotification object:self]; return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}


- (void)windowMoved:(id)notification
{
	NSPoint sOrigin = [[self screen] visibleFrame].origin;
	NSPoint fOrigin = [self frame].origin;
	NSPoint startPt	= fOrigin, endPt = [self frame].origin;
	float sWidth	= [[self screen] visibleFrame].size.width;
	float fWidth	= [self frame].size.width;
	
	if (!myMoving)
	{
		myMoving = YES;
		
		if (fOrigin.y < (sOrigin.y + kSnapFromNearEdge) && fOrigin.y > (sOrigin.y + kSnapFromBeyondEdge))
		{
			endPt.y = sOrigin.y;
		}
		
		if (fOrigin.x < (sOrigin.x + kSnapFromNearEdge) && fOrigin.x > (sOrigin.x + kSnapFromBeyondEdge))
		{
			endPt.x = sOrigin.x;
		}
		
		if ((fOrigin.x > (sOrigin.x + sWidth - fWidth - kSnapFromNearEdge)) && (fOrigin.x < (sOrigin.x + sWidth - fWidth - kSnapFromBeyondEdge)))
		{
			endPt.x = (sOrigin.x + sWidth - fWidth	);
		}
		
		if(!NSEqualPoints(startPt, endPt))
		{
			[self setFrameOrigin:endPt];
			usleep(kSleepMilliseconds * 1000);		// sleep a bit to let user do mouseup
		}
		myMoving = NO;
	}
}

@end