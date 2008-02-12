//
//  PlaceholderTableView.m
//  Amazon List
//
//  Created by Mike on 04/01/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTPlaceholderTableView.h"
#import "KTVerticallyAlignedTextCell.h"
#import "NSView+KTExtensions.h"


@interface KTPlaceholderTableView (Private)
- (KTVerticallyAlignedTextCell *)placeholderTextCell;
@end


@implementation KTPlaceholderTableView

# pragma mark *** Init & Dealloc ***

- (void)awakeFromNib
{
	// Monitor the clip view containing us
	[[self superview] setPostsBoundsChangedNotifications:YES];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(clipViewBoundsChanged:)
												 name:NSViewBoundsDidChangeNotification
											   object:[self superview]];
	
	// Add the progress indicator to ourself
	[self setLoadingData:NO];
	NSProgressIndicator *spinner = [self dataLoadingProgressIndicator];
	
	[self addSubview:spinner];
	[spinner centerInRect:[self bounds]];
	
}

- (void)dealloc
{
	// De-register from clip view notifications
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:NSViewBoundsDidChangeNotification
												  object:[self superview]];
	
	// Release ivars
	[myPlaceholder release];
	
	[myPlaceholderCell release];
	[myDataLoadingProgressIndicator release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (NSString *)placeholderString { return myPlaceholder; }

- (void)setPlaceholderString:(NSString *)placeholder
{
	placeholder = [placeholder copy];
	[myPlaceholder release];
	myPlaceholder = placeholder;
	
	[self setNeedsDisplay:YES];
}

- (NSColor *)placeholderStringColor { return [[self placeholderTextCell] textColor]; }

- (void)setPlaceholderStringColor:(NSColor *)color { [[self placeholderTextCell] setTextColor:color]; }

- (BOOL)isLoadingData { return myLoadingData; }

- (void)setLoadingData:(BOOL)loadingData
{
	// Store the value
	myLoadingData = loadingData;
	
	// Set the animation of the spinner
	NSProgressIndicator *spinner = [self dataLoadingProgressIndicator];
	if (loadingData) {
		[spinner startAnimation:self];
		[spinner setHidden:NO];
	}
	else {
		[spinner setHidden:YES];
		[spinner stopAnimation:self];
	}
}

# pragma mark *** Drawing ***

- (void)drawRect:(NSRect)aRect
{
	[super drawRect:aRect];
	
	// If there are no rows in the table, draw the placeholder
	if ([self numberOfRows] == 0 && [self placeholderString])
	{
		NSTextFieldCell *cell = [self placeholderTextCell];
		[cell setStringValue:[self placeholderString]];
		
		NSRect textRect = NSInsetRect([self bounds], 12.0, 12.0);
		[cell drawWithFrame:textRect inView:self];
	}
}

- (KTVerticallyAlignedTextCell *)placeholderTextCell
{
	if (!myPlaceholderCell)
	{
		// Create the new cell with appropriate attributes
		myPlaceholderCell = [[KTVerticallyAlignedTextCell alloc] initTextCell:@""];
		
		[myPlaceholderCell setAlignment:NSCenterTextAlignment];
		[myPlaceholderCell setVerticalAlignment:KTVerticalCenterTextAlignment];
		
		float fontSize = [NSFont systemFontSizeForControlSize:NSSmallControlSize];
		NSFont *font = [NSFont boldSystemFontOfSize:fontSize];
		[myPlaceholderCell setFont:font];
		[myPlaceholderCell setTextColor:[NSColor grayColor]];
	}
	
	return myPlaceholderCell;
}

# pragma mark *** Progress Indicator ***

- (void)clipViewBoundsChanged:(NSNotification *)notification
{
	// Position our progress indicator in the center of the visible rectangle
	NSClipView *clipView = [notification object];
	NSRect visibleDoc = [clipView documentVisibleRect];
	
	[[self dataLoadingProgressIndicator] centerInRect:visibleDoc];
}

- (NSProgressIndicator *)dataLoadingProgressIndicator;
{
	if (!myDataLoadingProgressIndicator)
	{
		myDataLoadingProgressIndicator =
			[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0.0, 0.0, 32.0, 32.0)];
		
		[myDataLoadingProgressIndicator setControlSize:NSRegularControlSize];
		[myDataLoadingProgressIndicator setIndeterminate:YES];
		[myDataLoadingProgressIndicator setStyle:NSProgressIndicatorSpinningStyle];
		[myDataLoadingProgressIndicator setDisplayedWhenStopped:YES];	/// It wasn't always drawing correctly before
		
		[myDataLoadingProgressIndicator sizeToFit];
	}
	
	return myDataLoadingProgressIndicator;
}

@end
