//
//  NTBoxView.m
//  Path Finder
//
//  Created by Steve Gehrman on Sat May 17 2003.
//  Copyright (c) 2003 CocoaTech. All rights reserved.
//
// HIGHLY MODIFIED TO FILL WITH GRADIENTS, DO PARTIAL BORDERS, ETC.

#import "NTBoxView.h"

void InterpolateGradient (void* info, float const* inData, float *outData);
void InterpolateBevel (void* info, float const* inData, float *outData);

/*
void Interpolate (void* info, float const* inData, float* outData)
{
	outData[0] = inData[0];
	outData[1] = sin(M_PI * inData[0]);
	outData[2] = 1.0;
	outData[3] = 1.0;
}

void Interpolate (void* info, float const* inData, float *outData)
{
	static float color1[4] = { 1.0f, 0.0f, 0.0f, 1.0f };
	static float color2[4] = { 1.0f, 1.0f, 0.0f, 1.0f };
	
	float a = inData[0];
	for(int i = 0; i < 4; i++)
		outData[i] = (1.0f-a)*color1[i] + a*color2[i];
}
*/
void InterpolateGradient (void* info, float const* inData, float *outData)
{
	float gray1 = (float) 0xE2 / 255.0;
	float gray2 = (float) 0xF8 / 255.0;
	
	float a = inData[0];
	int i;
	for(i = 0; i < 4; i++)
		outData[i] = (1.0f-a)*gray1 + a*gray2;
}

void InterpolateBevel (void* info, float const* inData, float *outData)
{
	float gray1 = (float) 240.0 / 255.0;
	float gray2 = (float) 254.0 / 255.0;
	
	float a = inData[0];
	int i;
	for(i = 0; i < 4; i++)
		outData[i] = (1.0f-a)*gray1 + a*gray2;
}


@interface NTBoxView (Private)
- (NSRect)frameRect;
- (NSRect)shadowRect;
- (NSRect)rectInsideFrame;
- (void)drawShadow;
- (BOOL)windowIsMetallic;

- (NSColor*)highlightColor;
- (NSColor*)lightHighlightColor;
- (NSColor*)shadowColor;

@end

@implementation NTBoxView

# pragma mark *** Dealloc ***

- (void)dealloc
{
	[myFrameColor release];
	
	[super dealloc];
}

# pragma mark *** Accessors ***

- (void) setBorderMask:(int)aMask;		// if not set -- zero -- all sides drawn.
{
	_borderMask = aMask;
}

- (void)setDrawsFrame:(BOOL)set;
{
    [self setDrawsFrame:set withShadow:NO];
}

- (void)setDrawsFrame:(BOOL)set withShadow:(BOOL)aShadow;
{
    _shadow = aShadow;
    _drawsFrame = set;
}

- (void)setFill:(int)inFill;
{
	_fill = inFill;
}

- (BOOL)drawsShadow;
{
    return _shadow;
}

- (BOOL)drawsFrame;
{
    return _drawsFrame;
}

// If no color has been set, use the default gray of 0.75
- (NSColor *)frameColor
{
	if (!myFrameColor) {
		myFrameColor = [[NSColor colorWithCalibratedWhite: 0.75 alpha: 1.0] retain];
	}
	
	return myFrameColor;
}

- (void)setFrameColor:(NSColor *)color
{
	[color retain];
	[myFrameColor release];
	myFrameColor = color;
}


- (NSRect)contentBounds;
{
    if (_drawsFrame)
    {
        NSRect result = [self bounds];
		
		if (0 == _borderMask || (_borderMask == (NTBoxLeft | NTBoxRight | NTBoxTop | NTBoxBottom)))
		{
			result = NSInsetRect(result, 1, 1);
		}
		else
		{
			if (_borderMask & NTBoxLeft)
			{
				result.origin.x += 1;
				result.size.width -= 1;
			}
			if (_borderMask & NTBoxRight)
			{
				result.size.width -= 1;
			}
			if (_borderMask & NTBoxTop)
			{
				result.size.height -= 1;
			}
			if (_borderMask & NTBoxBottom)
			{
				result.origin.y += 1;
				result.size.height -= 1;
			}
		}

        if ([self drawsShadow])
            result = NSInsetRect(result, 1, 1);

        return result;
    }
    
    return [self bounds];
}

# pragma mark *** Drawing ***

- (void)drawRect:(NSRect)frame;
{
	if (_fill == NTBoxGradient || _fill == NTBoxBevel)
	{
		NSEraseRect(frame);

		struct CGFunctionCallbacks callbacks = { 0, _fill == NTBoxGradient ? InterpolateGradient : InterpolateBevel, NULL };
		
		CGFunctionRef function = CGFunctionCreate(
												  NULL,       // void* info,
												  1,          // size_t domainDimension,
												  NULL,       // float const* domain,
												  4,          // size_t rangeDimension,
												  NULL,       // float const* range,
												  &callbacks  // CGFunctionCallbacks const* callbacks
												  );
		
		CGColorSpaceRef cspace = CGColorSpaceCreateDeviceRGB();
		
		NSRect bounds = [self contentBounds];
		float srcX = NSMinX(bounds), srcY = NSMinY(bounds) + 0.5;	// from lower left
		float dstX = NSMinX(bounds), dstY = NSMaxY(bounds) - 0.5;	// to upper left
		CGShadingRef shading = CGShadingCreateAxial(
													cspace,                    // CGColorSpaceRef colorspace,
													CGPointMake(srcX, srcY),   // CGPoint start,
													CGPointMake(dstX, dstY),   // CGPoint end,
													function,                  // CGFunctionRef function,
													false,                     // bool extendStart,
													false                      // bool extendEnd
													);
		
		CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
		CGContextDrawShading(
							 context,
							 shading
							 );
		
		CGShadingRelease(shading);
		CGColorSpaceRelease(cspace);
		CGFunctionRelease(function);
		
		if (_fill == NTBoxBevel)
		{
			NSRect fillFrame = [self rectInsideFrame];
			
			NSRect bottomFrame = NSMakeRect(fillFrame.origin.x,
											fillFrame.origin.y,
											fillFrame.size.width,
											floorf(fillFrame.size.height/2.0));
			
			[[NSColor colorWithCalibratedWhite:230.0/255.0 alpha:1.0] set];
			NSRectFill(bottomFrame);
		}
	}
	
	// Now back to usual NTBoxView stuff to do border and shadow
	
    if (_drawsFrame)
    {        
		NSRect frameRect = [self frameRect];
        [[self frameColor] set];
		
		if (0 == _borderMask || (_borderMask == (NTBoxLeft | NTBoxRight | NTBoxTop | NTBoxBottom)))
		{
			NSFrameRectWithWidth(frameRect, 1);
		}
		else
		{
			NSPoint a,b;
			if (_borderMask & NTBoxLeft)
			{
				a = NSMakePoint(NSMinX(frameRect)+0.5, NSMinY(frameRect));
				b = NSMakePoint(NSMinX(frameRect)+0.5, NSMaxY(frameRect));
				[NSBezierPath strokeLineFromPoint:a toPoint:b];
			}
			if (_borderMask & NTBoxRight)
			{
				a = NSMakePoint(NSMaxX(frameRect)-0.5, NSMinY(frameRect));
				b = NSMakePoint(NSMaxX(frameRect)-0.5, NSMaxY(frameRect));
				[NSBezierPath strokeLineFromPoint:a toPoint:b];
			}
			if (_borderMask & NTBoxTop)
			{
				a = NSMakePoint(NSMinX(frameRect), NSMaxY(frameRect)-0.5);
				b = NSMakePoint(NSMaxX(frameRect), NSMaxY(frameRect)-0.5);
				[NSBezierPath strokeLineFromPoint:a toPoint:b];
			}
			if (_borderMask & NTBoxBottom)
			{
				a = NSMakePoint(NSMinX(frameRect), NSMinY(frameRect)+0.5);
				b = NSMakePoint(NSMaxX(frameRect), NSMinY(frameRect)+0.5);
				[NSBezierPath strokeLineFromPoint:a toPoint:b];
			}
		}

        if ([self drawsShadow])
            [self drawShadow];
    }
	
}

@end

@implementation NTBoxView (Private)

- (NSRect)frameRect;
{
    NSRect result = [self bounds];
    
    if ([self drawsShadow])
        result = NSInsetRect(result, 1, 1);
        
    return result;
}

- (NSRect)shadowRect;
{
    if ([self drawsShadow])
        return [self bounds];
    
    return NSZeroRect;
}

/* Look at each side of the frame. If it set, reduce the size of the rectangle on that side */
- (NSRect)rectInsideFrame
{
	NSRect result = [self frameRect];
	
	if ([self drawsFrame])
	{
		if (_borderMask & NTBoxLeft) {
			result.origin.x += 1;
			result.size.width -= 1;
		}
		if (_borderMask & NTBoxBottom) {
			result.origin.y += 1;
			result.size.height -= 1;
		}
		if (_borderMask & NTBoxRight) {
			result.size.width -= 1;
		}
		if (_borderMask & NTBoxTop) {
			result.size.height -= 1;
		}
	}
	return result;
}

- (void)drawShadow;
{
    NSRect result = [self shadowRect];
    NSRect slice;
    
    // top
    if ([self windowIsMetallic])
        [[self shadowColor] set];
    else
        [[self highlightColor] set];

    NSDivideRect(result, &slice, &result, 1.0, NSMaxYEdge);
    slice.origin.x += 1;
    slice.size.width -= 2;
    [NSBezierPath fillRect:slice];
    
    // bottom
    [[self lightHighlightColor] set];
    NSDivideRect(result, &slice, &result, 1.0, NSMinYEdge);
    slice.origin.x += 1;
    slice.size.width -= 2;
    [NSBezierPath fillRect:slice];
    
    // right
    [[self highlightColor] set];
    NSDivideRect(result, &slice, &result, 1.0, NSMaxXEdge);
    [NSBezierPath fillRect:slice];
    
    // left
    [[self highlightColor] set];
    NSDivideRect(result, &slice, &result, 1.0, NSMinXEdge);
    [NSBezierPath fillRect:slice];
}

- (BOOL)windowIsMetallic;
{
    return (([[self window] styleMask] & NSTexturedBackgroundWindowMask) != 0);
}

- (NSColor*)shadowColor;
{
    static NSColor* shared = nil;
    
    if (!shared)
        shared = [[NSColor colorWithCalibratedWhite:.550 alpha:1.0] retain];
    
    return shared;
}

- (NSColor*)highlightColor;
{
    static NSColor* shared = nil;
    
    if (!shared)
        shared = [[NSColor colorWithCalibratedWhite:.850 alpha:1.0] retain];
    
    return shared;
}

- (NSColor*)lightHighlightColor;
{
    static NSColor* shared = nil;
    
    if (!shared)
        shared = [[NSColor colorWithCalibratedWhite:.950 alpha:1.0] retain];
    
    return shared;    
}

@end

