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

#pragma mark -

- copyWithZone:(NSZone *)zone
{
    KTImageTextCell *cell = (KTImageTextCell *)[super copyWithZone:zone];
    cell->myImage = [myImage retain];
	cell->myImageCell = [myImageCell copy];
	//cell->myStaleness = myStaleness;

    return cell;
}

/*	The rect to fit the text in
 */
- (NSRect)titleRectForBounds:(NSRect)theRect
{
	// Calculate the area to the left of the image
	NSRect nonImageRect;	NSRect otherRect;
	NSDivideRect(theRect,
				 &otherRect, &nonImageRect,
				 [self padding] + [self maxImageSize], NSMinXEdge);
	
	
	
	// Crop off the right-hand side of that rect to account for drafts/code injection
	float iconsWidth = 0.0;
	if ([self isDraft]) iconsWidth += 8.0;
	if ([self hasCodeInjection]) iconsWidth += [self codeInjectionIconWidth];
	
	NSRect almostResult;
	NSDivideRect(nonImageRect, &otherRect, &almostResult, iconsWidth, NSMaxXEdge);
	
	
	// We have to inset by a pixel for proper text drawing. Not sure why.
	NSRect result = NSInsetRect(almostResult, 1.0, 1.0);
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

- (void)editWithFrame:(NSRect)aRect
               inView:(NSView *)controlView
               editor:(NSText *)textObj
             delegate:(id)anObject
                event:(NSEvent *)theEvent
{
    NSRect textFrame, imageFrame;

    NSDivideRect(aRect, &imageFrame, &textFrame, myPadding + [myImage size].width, NSMinXEdge);

    [super editWithFrame:textFrame
                  inView:controlView
                  editor:textObj
                delegate:anObject
                   event:theEvent];
}

- (void)selectWithFrame:(NSRect)aRect
                 inView:(NSView *)controlView
                 editor:(NSText *)textObj
               delegate:(id)anObject
                  start:(int)selStart
                 length:(int)selLength
{
    NSRect textFrame, imageFrame;

    NSDivideRect(aRect, &imageFrame, &textFrame, myPadding + [myImage size].width, NSMinXEdge);

    [super selectWithFrame:textFrame
                    inView:controlView
                    editor:textObj
                  delegate:anObject
                     start:selStart
                    length:selLength];
}

- (void)drawDraftMarkersFrorFrame:(NSRect)cellFrame		// assumes focused
{
	if (myIsDraft)
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
	[self drawDraftMarkersFrorFrame:cellFrame];	// draw draft markers FIRST - will this work?
	[super drawWithFrame:cellFrame inView:controlView];
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
	
	
	// if drawing on top of a gradient, make the text color white
	if ([self isHighlighted] )
	{
		NSMutableAttributedString *newAttrString = [[[self attributedStringValue] mutableCopy] autorelease];
		[newAttrString addAttribute:@"NSColor" value:[NSColor whiteColor] range:NSMakeRange(0, [newAttrString length])];
		[self setAttributedStringValue:newAttrString];
	}
	
	//if ( [self type] == NSTextCellType )
	NSAttributedString *attributedString = [self attributedStringValue];
	NSSize stringSize = [attributedString size];
	NSRect textRect = [self titleRectForBounds:cellFrame];
	NSRect stringBoundingRect = [attributedString boundingRectWithSize:textRect.size options:(NSStringDrawingUsesFontLeading & NSStringDrawingOneShot)];
	
	// look at lineBreakMode and stringSize to calculate drawRect
	NSDictionary *stringAttributes = [attributedString attributesAtIndex:0 effectiveRange:NULL];
	NSParagraphStyle *style = [stringAttributes valueForKey:NSParagraphStyleAttributeName];
	if ( (nil != style)
		 && (!([style lineBreakMode] == NSLineBreakByWordWrapping) || (([style lineBreakMode] == NSLineBreakByWordWrapping) && stringSize.width <= cellFrame.size.width))
		 && (!([style lineBreakMode] == NSLineBreakByCharWrapping) || (([style lineBreakMode] == NSLineBreakByCharWrapping) && stringSize.width <= cellFrame.size.width)) )
	{
		// we're not wrapping, center vertically on single line
		textRect.origin.y += cellFrame.size.height/2.0-stringBoundingRect.size.height/2.0;
		textRect.size.height = stringBoundingRect.size.height;
	}
	else
	{
		// we're wrapping, center it vertically on multiple lines
		int numberOfLinesNeeded = ceil(stringSize.width/cellFrame.size.width);
		int numberOfLinesPossible = floor(cellFrame.size.height/stringSize.height);
		int numberOfLines = (numberOfLinesNeeded > numberOfLinesPossible) ? numberOfLinesPossible : numberOfLinesNeeded;
		if ( numberOfLines < 1 )
		{
			numberOfLines = 1;
		}
		textRect.origin.y += (cellFrame.size.height/2.0-(stringBoundingRect.size.height*numberOfLines)/2.0);
		textRect.size.height = stringBoundingRect.size.height * numberOfLines;
	}
	
	// draw the string
	[attributedString drawInRect:textRect];
}

- (NSSize)cellSize
{
	// expand cellSize my width of myImage + padding
    NSSize cellSize = [super cellSize];
    cellSize.width += (myImage ? [myImage size].width : 0) + myPadding;
    return cellSize;
}

#pragma mark -
#pragma mark Accessors

- (BOOL)isDraft { return myIsDraft; }

- (void)setDraft:(BOOL)flag { myIsDraft = flag; }

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
