//
//  KTImageTextCell.m
//  OutlineViewTester
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
//

// a few additions to Chuck's ImageAndTextCell class

#import "KTImageTextCell.h"

#import "KT.H"


#define DEFAULT_PADDING 4   // eyeball guess, 4 is a standard Aqua spacing


void InterpolateCurveShadow (void* info, float const* inData, float *outData)
{
	static float color1[4] = { 0.00, 0.00, 0.00, 0.0f };
	static float color2[4] = { 0.00, 0.00, 0.00, 0.6f };
	int i;
	float a = inData[0];
	for(i = 0; i < 4; i++)
		outData[i] = (1.0f-a)*color1[i] + a*color2[i];
}

void InterpolateCurveGloss (void* info, float const* inData, float *outData)
{
	static float color1[4] = { 1.0, 1.0, 1.0, 0.2f };		// VERY subtle lightening
	static float color2[4] = { 1.0, 1.0, 1.0, 0.0f };
	int i;
	float a = inData[0];
	for(i = 0; i < 4; i++)
		outData[i] = (1.0f-a)*color1[i] + a*color2[i];
}


@interface KTImageTextCell ()
+ (NSImage *)codeInjectionIcon;
- (float)codeInjectionIconWidth;
@end


@implementation KTImageTextCell

- (id)init
{
    self = [super init];
    if ( self ) 
	{
        [self setImage:nil];
        [self setPadding:DEFAULT_PADDING];
//		[self setStaleness:kNotStale]; // enum removed, staleness flag has changed
        
		myImageCell = [[NSImageCell alloc] initImageCell:nil];
		[myImageCell setImageAlignment:NSImageAlignCenter];
		[myImageCell setImageScaling:NSScaleProportionally];
    }

    return self;
}

- (void)dealloc
{
    [myImage release];
    [super dealloc];
}

#pragma mark NSCopying

- copyWithZone:(NSZone *)zone
{
    KTImageTextCell *cell = (KTImageTextCell *)[super copyWithZone:zone];
    cell->myImage = [myImage retain];
	cell->myImageCell = [myImageCell copy];
	//cell->myStaleness = myStaleness;

    return cell;
}

#pragma mark Layout

- (NSSize)cellSize
{
	// expand cellSize my width of myImage + padding
    NSSize cellSize = [super cellSize];
    cellSize.width += (myImage ? [myImage size].width : 0) + myPadding;
    return cellSize;
}

/*	The rect to fit the text in
 */
- (NSRect)titleRectForBounds:(NSRect)theRect
{
    // Start with the default size
    theRect = [super titleRectForBounds:theRect];
    
	// Calculate the area to the left of the image
	NSRect nonImageRect;	NSRect otherRect;
	NSDivideRect(theRect,
				 &otherRect, &nonImageRect,
				 [self padding] + [self maxImageSize], NSMinXEdge);
	
	
	
	// Crop off the right-hand side of that rect to account for drafts/code injection
	float iconsWidth = 0.0;
	if ([self isDraft]) iconsWidth += 8.0;
	if ([self hasCodeInjection]) iconsWidth += [self codeInjectionIconWidth];
	
	NSRect result;
	NSDivideRect(nonImageRect, &otherRect, &result, iconsWidth, NSMaxXEdge);
	
	
	return result;
}

/*	The frame for image to fit inside for the specified cellFrame
 */
- (NSRect)imageRectForBounds:(NSRect)cellFrame
{
    NSRect result = NSMakeRect(cellFrame.origin.x + [self padding],
							   cellFrame.origin.y + 1.0,
							   [self maxImageSize],
							   [self maxImageSize]);
	
	if ([self isRoot])
	{
		result.origin.y += 12.0;
	}
	
	return result;
}

#pragma mark Drawing

- (void)drawNotPublishableMarkersWithFrame:(NSRect)cellFrame
{
	if (![self isPublishable])
	{
		static NSColor *sNotPublishablePattern = nil;
		if (nil == sNotPublishablePattern)
		{
			NSImage *notPublishablePatternImage = [NSImage imageNamed:@"notPublishable"];		// TO FIX
			sNotPublishablePattern = [[NSColor colorWithPatternImage:notPublishablePatternImage] retain];
		}
		[NSGraphicsContext saveGraphicsState];
		[[NSGraphicsContext currentContext] setCompositingOperation:NSCompositePlusDarker];
		[sNotPublishablePattern set];
		NSRect theRect = NSMakeRect(cellFrame.origin.x,
									  cellFrame.origin.y,
									  cellFrame.size.width,
									  cellFrame.size.height+1);		// one pixel taller so it will bleed with adjacent row
		[NSBezierPath fillRect:theRect];
		[NSGraphicsContext restoreGraphicsState];
		
	}
}
- (void)drawDraftMarkersWithFrame:(NSRect)cellFrame		// assumes focused
{
	if ([self isDraft])
	{
		static NSColor *sDraftPattern = nil;
		if (nil == sDraftPattern)
		{
			NSImage *draftPatternImage = [NSImage imageNamed:@"draftPattern"];
			sDraftPattern = [[NSColor colorWithPatternImage:draftPatternImage] retain];
		}
		[NSGraphicsContext saveGraphicsState];
		[sDraftPattern set];
#define DRAFT_WIDTH 8
		NSRect draftRect = NSMakeRect(cellFrame.origin.x + cellFrame.size.width - DRAFT_WIDTH,
									  cellFrame.origin.y,
									  DRAFT_WIDTH,
									  cellFrame.size.height+1);		// one pixel taller so it will bleed with adjacent row
		[NSBezierPath fillRect:draftRect];
		[NSGraphicsContext restoreGraphicsState];
		[NSGraphicsContext saveGraphicsState];
		[NSBezierPath clipRect:draftRect];
		
		// Draw a gradient to darken the right side of things
		
		[[NSGraphicsContext currentContext] setCompositingOperation:NSCompositePlusDarker];
		{
			struct CGFunctionCallbacks callbacks = { 0, InterpolateCurveShadow, NULL };
			
			CGFunctionRef function = CGFunctionCreate(
													  NULL,       // void* info,
													  1,          // size_t domainDimension,
													  NULL,       // float const* domain,
													  4,          // size_t rangeDimension,
													  NULL,       // float const* range,
													  &callbacks  // CGFunctionCallbacks const* callbacks
													  );
			
			CGColorSpaceRef cspace = CGColorSpaceCreateDeviceRGB();
			
			float srcX = NSMinX(draftRect) + DRAFT_WIDTH/4	, srcY = NSMinY(draftRect);	// from a bit over from the lower left
			float dstX = NSMaxX(draftRect)					, dstY = NSMinY(draftRect);	// to lower right
			
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
		}
		
		
		// Draw a lightening "gloss" on the left edge
		
		[[NSGraphicsContext currentContext] setCompositingOperation:NSCompositePlusLighter];
		{
			struct CGFunctionCallbacks callbacks = { 0, InterpolateCurveGloss, NULL };
			
			CGFunctionRef function = CGFunctionCreate(
													  NULL,       // void* info,
													  1,          // size_t domainDimension,
													  NULL,       // float const* domain,
													  4,          // size_t rangeDimension,
													  NULL,       // float const* range,
													  &callbacks  // CGFunctionCallbacks const* callbacks
													  );
			
			CGColorSpaceRef cspace = CGColorSpaceCreateDeviceRGB();
			
			float srcX = NSMinX(draftRect), srcY = NSMinY(draftRect);	// from   lower left
			float dstX = NSMinX(draftRect) + DRAFT_WIDTH / 4, dstY = NSMinY(draftRect);	// to a bit over toward the middle
			
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
		}
		
		[NSGraphicsContext restoreGraphicsState];
	}
}

// draw cell background
- (void)drawWithFrame:(NSRect)cellFrame
               inView:(NSView *)controlView
{
	[self drawDraftMarkersWithFrame:cellFrame];	// draw draft markers FIRST - will this work?
	[super drawWithFrame:cellFrame inView:controlView];
	[self drawNotPublishableMarkersWithFrame:cellFrame];	// draw afterwards so it goes on top
}

// draw cell interior (image and text)
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	// fix for 7294: don't lockFocus in this method, it alters the coords

	// draw image
	if ( myImage != nil ) 
	{
		// Draw image
        NSRect	imageFrame = [self imageRectForBounds:cellFrame];
		[myImageCell drawWithFrame:imageFrame inView:controlView];
		
		
		// Draw staleness indicator, if appropriate
		if ([self staleness])
		{
			NSRect markerRect = NSMakeRect(imageFrame.origin.x, NSMaxY(imageFrame) - 3.0, 3.0, 3.0);
			NSBezierPath *markerPath = [NSBezierPath bezierPathWithOvalInRect:markerRect];
			[markerPath setLineWidth:0.0];
			
			[[NSColor colorWithCalibratedRed:0.094 green:0.301 blue:0.75 alpha:1.0] setFill];
			[markerPath fill];
		}
    }
	
	
	// Draw Code Injection icon if needed
	if ([self hasCodeInjection])
	{
		NSRect codeInjectionIconRect = [self codeInjectionIconRectForBounds:cellFrame];
		NSImage *codeInjectionIcon = [[self class] codeInjectionIcon];
		[codeInjectionIcon drawInRect:codeInjectionIconRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	}
	
	
    // Draw text
    [self drawTitleWithFrame:cellFrame inView:controlView];
}

- (NSRect)titleDrawingRectForBounds:(NSRect)cellFrame
{
    //  The title rect encompasses the full height of the cell. This narrows it down to the height of the text, centered in that rectangle
    
    
    // What rect is the title to be drawn in?
    NSRect titleRect = [self titleRectForBounds:cellFrame];
    
    // Center vertically within that (taken from KSVerticallyAlignedTextCell).
    NSSize textSize = [super cellSizeForBounds:titleRect];
	CGFloat verticalInset = (cellFrame.size.height - textSize.height) / 2;
	NSRect result = NSInsetRect(titleRect, 0.0, verticalInset);
	
    
    return result;
}

- (void)drawTitleWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
{
    // What rect is the title to be drawn in?
    NSRect centeredRect = [self titleDrawingRectForBounds:cellFrame];
    [super drawInteriorWithFrame:centeredRect inView:controlView];
}

#pragma mark Editing

- (void)editWithFrame:(NSRect)cellFrame
               inView:(NSView *)controlView
               editor:(NSText *)textObj
             delegate:(id)anObject
                event:(NSEvent *)theEvent
{
    [super editWithFrame:[self titleDrawingRectForBounds:cellFrame]
                  inView:controlView
                  editor:textObj
                delegate:anObject
                   event:theEvent];
}

- (void)selectWithFrame:(NSRect)cellFrame
                 inView:(NSView *)controlView
                 editor:(NSText *)textObj
               delegate:(id)anObject
                  start:(int)selStart
                 length:(int)selLength
{
    [super selectWithFrame:[self titleDrawingRectForBounds:cellFrame]
                    inView:controlView
                    editor:textObj
                  delegate:anObject
                     start:selStart
                    length:selLength];
}

#pragma mark -
#pragma mark Accessors

- (BOOL)isDraft { return myIsDraft; }

- (void)setDraft:(BOOL)flag { myIsDraft = flag; }

- (BOOL)isPublishable { return myIsPublishable; }

- (void)setPublishable:(BOOL)flag { myIsPublishable = flag; }

- (int)staleness { return myStaleness; }

- (void)setStaleness:(int)aStaleness { myStaleness = aStaleness; }

- (NSImage *)image { return myImage; }

- (void)setImage:(NSImage *)anImage
{
    if ( myImage != anImage ) 
	{
        [myImage release];
        myImage = [anImage retain];
		
		[myImageCell setImage:anImage];
    }
}

- (float)maxImageSize { return myMaxImageSize; }

- (void)setMaxImageSize:(float)width { myMaxImageSize = width; }

/*
- (void)setImagePosition:(NSCellImagePosition)aPosition
{
    // only NSImageLeft and NSImageRight are accepted
    if ( (aPosition != NSImageLeft) && (aPosition != NSImageRight) )
	{
        NSLog(@"%@ only NSImageLeft or NSImageRight allowed!", NSStringFromSelector(_cmd));
        return;
    }

    myImagePosition = aPosition;
}
*/

- (int)padding { return myPadding; }

- (void)setPadding:(int)anInt { myPadding = anInt; }

- (BOOL)isRoot { return myIsRoot; }

- (void)setRoot:(BOOL)isRoot { myIsRoot = isRoot; }

#pragma mark -
#pragma mark Code Injection

- (BOOL)hasCodeInjection { return myHasCodeInjection; }

- (void)setHasCodeInjection:(BOOL)flag { myHasCodeInjection = flag; }

+ (NSImage *)codeInjectionIcon
{
	static NSImage *result;
	
	if (!result)
	{
		result = [[NSImage imageNamed:@"syringe"] retain];
		[result setFlipped:YES];
	}
	
	return result;
}

- (NSRect)codeInjectionIconRectForBounds:(NSRect)cellFrame
{
	// Get a slice of the right width from the right-hand edge
	NSRect sliceRect;	NSRect otherRect;
	float iconSize = [self codeInjectionIconWidth];
	NSDivideRect(cellFrame, &sliceRect, &otherRect, iconSize, NSMaxXEdge);
	
	// Budge sideways if a draft
	if ([self isDraft]) sliceRect.origin.x -= 8.0;
	
	// Inset to get the right height & vertical location
	NSRect result = NSInsetRect(sliceRect, 0.0, (cellFrame.size.height - iconSize) / 2);
	
	return result;
}

- (float)codeInjectionIconWidth
{
	float result;
	if ([self controlSize] == NSRegularControlSize)
	{
		result = 20.0;
	}
	else
	{
		result = 14.0;
	}
	
	return result;
}

@end
