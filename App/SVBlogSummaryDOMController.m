//
//  SVBlogSummaryDOMController.m
//  Sandvox
//
//  Created by Dan Wood on 1/29/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVBlogSummaryDOMController.h"
#import "SVBlogEntryBorderView.h"

#import "DOMNode+Karelia.h"


@implementation SVBlogSummaryDOMController

- (NSRect)drawingRect;  // expressed in our DOM node's document view's coordinates
{
	NSRect result = [super drawingRect];
	
	SVBlogEntryBorderView *blogStuff = [[[SVBlogEntryBorderView alloc] init] autorelease];
	NSRect controlsDrawingRect = [blogStuff drawingRectForGraphicBounds:[[self HTMLElement] boundingBox]];

	result = NSUnionRect(result, controlsDrawingRect);
    return result;
}

- (void)drawRect:(NSRect)dirtyRect inView:(NSView *)view;
{
    if ([self isSelected])
    {
        // Draw if we're in the dirty rect (otherwise drawing can get pretty pricey)
        DOMElement *element = [self HTMLElement];
        NSRect frameRect = [view convertRect:[element boundingBox]
                                    fromView:[element documentView]];
		
		// special controls for blog stuff. Probably refactor this out to some specific place
		SVBlogEntryBorderView *blogStuff = [[[SVBlogEntryBorderView alloc] init] autorelease];
		NSRect controlsDrawingRect = [blogStuff drawingRectForGraphicBounds:frameRect];
        if ([view needsToDrawRect:controlsDrawingRect])
        {
            [blogStuff drawWithGraphicBounds:frameRect inView:view];
        }
		
    }
	[super drawRect:dirtyRect inView:view];		// draw the stuff that superclass would draw
}



@end
