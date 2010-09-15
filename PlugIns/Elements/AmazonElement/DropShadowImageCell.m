//
//  DropShadowImageCell.m
//  Amazon List
//
//  Created by Mike on 09/01/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "DropShadowImageCell.h"

#import "SandvoxPlugin.h"


@interface DropShadowImageCell ()
- (void)drawShadowWithFrame:(NSRect)shadowFrame;
@end


@implementation DropShadowImageCell

- (id)initWithCoder:(NSCoder *)decoder
{
	[super initWithCoder: decoder];
	
	//[self setImageScaling: NSScaleToFit];	// This ensures our frame calculations are correct later on
	
	return self;
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSImage *image = [self objectValue];
	
	
	// Don't bother drawing if there is no image
	if (!image) {
		return;
	}
	
	
	// The frame available for the image to be drawn in
	NSSize imageSize = [image size];
	NSRect maxImageFrame = NSInsetRect(cellFrame, 3.0, 3.0);
	maxImageFrame.size.height -= 1.0;
	
	
	// Find the size of the image to be drawn
	// Pick the smallest scaling factor that ensures the image fits within the frame
	float xScaleFactor = maxImageFrame.size.width / imageSize.width;
	float yScaleFactor = maxImageFrame.size.height / imageSize.height;
	
	NSSize drawingSize;
	if (yScaleFactor < xScaleFactor)
	{
		float imageWidth = roundf(yScaleFactor * imageSize.width);
		drawingSize = NSMakeSize(imageWidth, maxImageFrame.size.height);
	}
	else
	{
		float imageHeight = roundf(xScaleFactor * imageSize.height);
		drawingSize = NSMakeSize(maxImageFrame.size.width, imageHeight);
	}
	
		
	// Find the rectangle to draw the image in
	float xInset = (maxImageFrame.size.width - drawingSize.width) / 2;
	float yInset = (maxImageFrame.size.height - drawingSize.height) / 2;
	
	NSRect drawingRect = NSIntegralRect(NSInsetRect(maxImageFrame, xInset, yInset));
	
	
	// Draw the shadow and then the image
	[self drawShadowWithFrame: drawingRect];
	[super drawWithFrame: drawingRect inView: controlView];
}

- (void)drawShadowWithFrame:(NSRect)shadowFrame
{
	[NSGraphicsContext saveGraphicsState];
	
	// Create and set the shadow
	NSShadow *theShadow = [[NSShadow alloc] init];
	[theShadow setShadowOffset: NSMakeSize(1.0, -3.0)];
	[theShadow setShadowBlurRadius: 3.0];
	[theShadow setShadowColor: [NSColor blackColor]];
	[theShadow set];
	
	// Draw a white rectangle, to draw the shadow around it
	NSEraseRect(shadowFrame);
	
	// Tidy up
	[theShadow release];
	[NSGraphicsContext restoreGraphicsState];
}

@end
