//
//  KTCircularProgressCell.m
//  Marvel
//
//  Created by Greg Hulands on 10/01/06.
//  Copyright 2006 Karelia Software. All rights reserved.
//

#import "KTCircularProgressCell.h"

#define CELL_PADDING 5

static inline NSRect KTCenteredSquareFromRect(NSRect aRect)
{
	NSRect newRect = aRect;
	if (NSWidth(aRect) > NSHeight(aRect)) {
		newRect.size.width = NSHeight(aRect);
	} else {
		newRect.size.height = NSWidth(aRect);
	}
	return NSOffsetRect(newRect, CELL_PADDING, 0);
}

static NSMutableParagraphStyle *OATextWithIconCellParagraphStyle = nil;

@implementation KTCircularProgressCell

+ (void)initialize;
{    
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    OATextWithIconCellParagraphStyle = [[NSMutableParagraphStyle alloc] init];
    [OATextWithIconCellParagraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
	[pool release];
}

- (id)init
{
	if (self = [super initTextCell:@""]) {
		NSBundle *b = [NSBundle bundleForClass:[self class]];
		NSString *p = [b pathForResource:@"upload_complete" ofType:@"png"];
		myImage = [[NSImage alloc] initWithContentsOfFile:p];
		p = [b pathForResource:@"upload_warning" ofType:@"png"];
		myWarningImage = [[NSImage alloc] initWithContentsOfFile:p];
		myColor = [[NSColor colorForControlTint:NSDefaultControlTint] retain];
	}
	return self;
}

- (void)dealloc
{
	[myWarningImage release];
	[myColor release];
	[myImage release];
	[myProgress release];
	[super dealloc];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	int percent = [[self progress] intValue];
	NSRect centered = KTCenteredSquareFromRect(cellFrame);
	
	//draw the name - this is borrowed from omni's imagetextcell
	// Draw the text
	NSMutableAttributedString *label = [[NSMutableAttributedString alloc] initWithAttributedString:[self attributedStringValue]];
	NSRange labelRange = NSMakeRange(0, [label length]);
	if ([NSColor respondsToSelector:@selector(alternateSelectedControlColor)]) {
		NSColor *highlightColor = [self highlightColorWithFrame:cellFrame inView:controlView];
		BOOL highlighted = [self isHighlighted];
		
		if (highlighted && [highlightColor isEqual:[NSColor alternateSelectedControlColor]]) {
            // add the alternate text color attribute.
			[label addAttribute:NSForegroundColorAttributeName value:[NSColor alternateSelectedControlTextColor] range:labelRange];
		}
	}
	
	[label addAttribute:NSParagraphStyleAttributeName value:OATextWithIconCellParagraphStyle range:labelRange];
	NSSize size = [label size];
	NSRect txtRect = NSMakeRect(NSMaxX(centered) + CELL_PADDING,  
								NSMidY(cellFrame) - (size.height / 2),
								NSWidth(cellFrame) - NSWidth(centered) - CELL_PADDING,
								size.height);
	[label drawInRect:txtRect];
	[label release];
	
	// don't draw anything for progress of 0%
	if (percent == 0) return;
	
	if (percent < 0) //we want to show a warning icon
	{
		
	}
	
	if (percent < 100 && percent > 0) 
	{
		NSAffineTransform *t = nil;
		if ([controlView isFlipped]) 
		{
			[[NSGraphicsContext currentContext] saveGraphicsState];
			t = [NSAffineTransform transform];
			[t translateXBy:0 yBy:NSMaxY(centered)];
			[t scaleXBy:1 yBy:-1];
			[t concat];
			centered.origin.y = 0;
		}
		// draw percentage progress
		NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:centered];
		NSPoint centerPoint = NSMakePoint(NSMidX(centered), NSMidY(centered));
		NSBezierPath *filler = [NSBezierPath bezierPath];
		float degrees = (percent / 100.0) * 360.0;
		
		[filler moveToPoint:centerPoint];
		// start top dead center
		[filler lineToPoint:NSMakePoint(NSMidX(centered), NSMaxY(centered))];
		
		//draw little ass segments - not ideal but it is late and I can't think straight
		int i;
		float radius = floor(NSMaxY(centered) - NSMidY(centered));
		float x, y;
		for (i = 0; i <= floor(degrees); i++) {
			float rad = i * (M_PI / 180.0);
			x = sinf(rad) * radius;
			y = cosf(rad) * radius;
			[filler lineToPoint:NSMakePoint(centerPoint.x + x, centerPoint.y + y)];
		}
		[filler lineToPoint:centerPoint];
		[filler closePath];
		
		[[NSColor whiteColor] set];
		[circle fill];
		[[myColor colorWithAlphaComponent:0.5] set];
		[filler fill];
		[myColor set];
		[filler setLineWidth:1.0];
		[filler stroke];
		[circle setLineWidth:1.0];
		[circle stroke];
		if ([controlView isFlipped]) {
			[t invert];
			[t concat];
			[[NSGraphicsContext currentContext] restoreGraphicsState];
		}
	} else {
		// show completed image
		if ([controlView isFlipped]) {
			[myImage setFlipped:YES];
		} else {
			[myImage setFlipped:NO];
		}
		[myImage drawInRect:centered fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	}
}

- (void)setObjectValue:(id <NSObject, NSCopying>)obj;
{
    if ([obj isKindOfClass:[NSString class]] || [obj isKindOfClass:[NSAttributedString class]]) {
        [super setObjectValue:obj];
        return;
    } else if ([obj isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = (NSDictionary *)obj;
        
        [super setObjectValue:[dictionary objectForKey:@"name"]];
        [self setProgress:[dictionary objectForKey:@"progress"]];
    }
}

- (void)setProgress:(NSNumber *)progress
{
	[myProgress autorelease];
	myProgress = [progress copy];
}

- (NSNumber *)progress
{
	return myProgress;
}

- (void)setCompletedImage:(NSImage *)image
{
	[myImage autorelease];
	myImage = [image retain];
}

- (NSImage *)completedImage
{
	return myImage;
}

- (void)setColor:(NSColor *)color
{
	[myColor autorelease];
	myColor = [color copy];
}

- (NSColor *)color
{
	return myColor;
}

- (id)objectValue
{
	return [[myProgress copy] autorelease];
}

@end
