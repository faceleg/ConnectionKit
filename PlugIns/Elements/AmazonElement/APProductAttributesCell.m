//
//  APProductAttributesCell.m
//  Amazon List
//
//  Created by Mike on 30/12/2006.
//  Copyright 2006-2009 Karelia Software. All rights reserved.
//

#import "APProductAttributesCell.h"

#import "AmazonListProduct.h"
#import "APManualListProduct.h"
#import "APAutomaticListProduct.h"


@interface APProductAttributesCell ()

- (KSVerticallyAlignedTextCell *)textDrawingCell;
- (void)drawProductLoadingError:(NSError *)error withFrame:(NSRect)cellFrame inView:(NSView *)controlView;

- (void)drawSingleLine:(NSString *)line
			 withFrame:(NSRect)cellFrame
			    inView:(NSView *)controlView
	 allowTextWrapping:(BOOL)wrap
			   useGray:(BOOL)gray;

- (void)drawLine1:(NSString *)line1
			line2:(NSString *)line2
		withFrame:(NSRect)cellFrame
		   inView:(NSView *)controlView
		  useGray:(BOOL)gray;

@end


@implementation APProductAttributesCell

#pragma mark -
#pragma mark Copy & Dealloc

- (id)copyWithZone:(NSZone *)zone
{
	APProductAttributesCell *copy = [super copyWithZone: zone];
	
	copy -> myTextDrawingCell = nil;
	
	return copy;
}

- (void)dealloc
{
	[myTextDrawingCell release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Drawing

- (KSVerticallyAlignedTextCell *)textDrawingCell
{
	// Create the cell if needed
	if (!myTextDrawingCell)
	{
		myTextDrawingCell = [[KSVerticallyAlignedTextCell alloc] initTextCell: @""];
		
		NSFont *cellFont = [NSFont boldSystemFontOfSize:
			[NSFont systemFontSizeForControlSize: NSSmallControlSize]];
		[myTextDrawingCell setFont: cellFont];
		
		[myTextDrawingCell setAlignment: NSLeftTextAlignment];
		[myTextDrawingCell setWraps: NO];
		[myTextDrawingCell setLineBreakMode: NSLineBreakByTruncatingTail];
		[myTextDrawingCell setAllowsEditingTextAttributes: NO];
		
		[myTextDrawingCell setBezeled: NO];
		[myTextDrawingCell setBordered: NO];
	}
	
	return [[myTextDrawingCell copy] autorelease];	// We want drawing performed with a copy of the cell
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	id product = [self objectValue];
	NSString *productCode = [product ASIN];
	NSString *productTitle = [product title];
	
	
	// How should we display the product?
	if ([product isLoadingData])
	{
		[self drawSingleLine: LocalizedStringInThisBundle(@"Loading product data\\U2026", @"table cell")
				   withFrame: cellFrame
					  inView: controlView
		   allowTextWrapping: YES
					 useGray: NO];
	}
	else if (!productCode || [productCode isEqualToString: @""])
	{
		[self drawSingleLine: LocalizedStringInThisBundle(@"Please specify an Amazon product to display", @"table cell")
				   withFrame: cellFrame
					  inView: controlView
		   allowTextWrapping: YES
					 useGray: NO];
	}
	else if ([product isKindOfClass:[APManualListProduct class]] && [product lastLoadError])
	{
		[self drawProductLoadingError:[product lastLoadError] withFrame:cellFrame inView:controlView];
	}
	else if (!productTitle)
	{
		[self drawSingleLine: LocalizedStringInThisBundle(@"No matching Amazon product found", @"table cell")
				   withFrame: cellFrame
					  inView: controlView
		   allowTextWrapping: YES
					 useGray: NO];
	}
	else
	{
		// If this is an wishlist product draw in grey if enough have been received.
		BOOL hasBeenReceived = NO;
		if ([product isKindOfClass: [APAutomaticListProduct class]]) {
			hasBeenReceived = [(APAutomaticListProduct *)product desiredQuantityHasBeenReceived];
		}
		
		NSString *creator = [product creator];
		
		// If available, draw creator as well
		if (creator && ![creator isEqualToString: @""]) {
			[self drawLine1: productTitle
					  line2: creator
				  withFrame: cellFrame
				     inView: controlView
					useGray: hasBeenReceived];
		}
		else {
			[self drawSingleLine: productTitle
					   withFrame: cellFrame
						  inView: controlView
			   allowTextWrapping: NO
						 useGray: hasBeenReceived];
		}
	}
}

/* Figure out how to display the error */
- (void)drawProductLoadingError:(NSError *)error withFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSString *errorDomain = [error domain];
	NSString *errorDescription = LocalizedStringInThisBundle(@"There was an error loading the product", @"table cell");
	
	if ([errorDomain isEqualToString:NSURLErrorDomain])
	{
		// We have a special error for no Internet connection
		if ([error code] == -1009) {
			errorDescription = LocalizedStringInThisBundle(@"No Internet connection", @"table cell");
		 }
	}
	else if ([errorDomain isEqualToString:@"AmazonECSOperationError"])
	{
		errorDescription = LocalizedStringInThisBundle(@"No matching Amazon product found", @"table cell");
	}
	
	
	[self drawSingleLine: errorDescription
			   withFrame: cellFrame
				  inView: controlView
	   allowTextWrapping: YES
				 useGray: NO];
}

- (void)drawSingleLine:(NSString *)line
			 withFrame:(NSRect)cellFrame
			    inView:(NSView *)controlView
	 allowTextWrapping:(BOOL)wrap
			   useGray:(BOOL)gray
{
	KSVerticallyAlignedTextCell *drawingCell = [self textDrawingCell];
	
	// Set the wrapping behaviour of the cell
	if (wrap)
	{
		[drawingCell setWraps: YES];
		[drawingCell setLineBreakMode: NSLineBreakByWordWrapping];
	}
	if (gray) {
		[drawingCell setTextColor: [NSColor grayColor]];
	}
	
	// Draw the single line of text in the centre of the cell
	[drawingCell setStringValue: line];
	[drawingCell setVerticalAlignment: KSVerticalCenterTextAlignment];
	
	[drawingCell drawWithFrame: cellFrame inView: controlView];
}

- (void)drawLine1:(NSString *)line1
			line2:(NSString *)line2
		withFrame:(NSRect)cellFrame
		   inView:(NSView *)controlView
		  useGray:(BOOL)gray
{
	// Divide the frame vertically in half
	float halfHeight = roundf(cellFrame.size.height / 2);
	NSRect topRect;
	NSRect bottomRect;
	NSDivideRect(cellFrame, &bottomRect, &topRect, halfHeight, NSMaxYEdge);
	
	
	// Draw the lines
	KSVerticallyAlignedTextCell *cell = [self textDrawingCell];
	if (gray) {
		[cell setTextColor: [NSColor grayColor]];
	}
	
	[cell setStringValue: line1];
	[cell setVerticalAlignment: KSBottomTextAlignment];
	[cell drawWithFrame: topRect inView: controlView];
	
	[cell setStringValue: line2];
	[cell setVerticalAlignment: KSTopTextAlignment];
	[cell drawWithFrame: bottomRect inView: controlView];
}

@end
