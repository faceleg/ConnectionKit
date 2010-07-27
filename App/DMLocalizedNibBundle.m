//  DMLocalizedNibBundle.m
//
//  Created by William Jon Shipley on 2/13/05.
//  Copyright © 2005-2009 Golden % Braeburn, LLC. All rights reserved except as below:
//  This code is provided as-is, with no warranties or anything. You may use it in your projects as you wish, but you must leave this comment block (credits and copyright) intact. That's the only restriction -- Golden % Braeburn otherwise grants you a fully-paid, worldwide, transferrable license to use this code as you see fit, including but not limited to making derivative works.
//
//
// Modified by Dan Wood of Karelia Software
//
// Some of this is inspired and modified by GTMUILocalizer from Google Toolbox http://google-toolbox-for-mac.googlecode.com
// (BSD license)

// KNOWN LIMITATIONS
//
// NOTE: NSToolbar localization support is limited to only working on the
// default items in the toolbar. We cannot localize items that are on of the
// customization palette but not in the default items because there is not an
// API for NSToolbar to get all possible items. You are responsible for
// localizing all non-default toolbar items by hand.
//
// Due to technical limitations, accessibility description cannot be localized.
// See http://lists.apple.com/archives/Accessibility-dev/2009/Dec/msg00004.html
// and http://openradar.appspot.com/7496255 for more information.


#define DEBUG_THIS_USER @"dwood"

#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "Debug.h"

#import "NSString+Karelia.h"



// ===========================================================================
// Based on GTMUILocalizerAndTweaker.m

static BOOL IsRightAnchored(NSView *view) {
	NSUInteger autoresizing = [view autoresizingMask];
	BOOL viewRightAnchored =
	((autoresizing & (NSViewMinXMargin | NSViewMaxXMargin)) == NSViewMinXMargin);
	return viewRightAnchored;
}

// Constant for a forced string wrap in button cells (Opt-Return in IB inserts
// this into the string).
NSString * const kForcedWrapString = @"\xA";
// Radio and Checkboxes (NSButtonCell) appears to use two different layout
// algorithms for sizeToFit calls and drawing calls when there is a forced word
// wrap in the title.  The result is a sizeToFit can tell you it all fits N
// lines in the given rect, but at draw time, it draws as >N lines and never
// gets as wide, resulting in a clipped control.  This fudge factor is what is
// added to try and avoid these by giving the size calls just enough slop to
// handle the differences.
// radar://7831901 different wrapping between sizeToFit and drawing
static const CGFloat kWrapperStringSlop = 0.9;

static NSSize ResizeToFit(NSView *view)
{
	
//	// If we've got one of us within us, recurse (for grids)
//	if ([view isKindOfClass:[GTMWidthBasedTweaker class]]) {
//		GTMWidthBasedTweaker *widthAlignmentBox = (GTMWidthBasedTweaker *)view;
//		return NSMakeSize([widthAlignmentBox tweakLayoutWithOffset:offset], 0);
//	}
	
	NSRect oldFrame = [view frame];		// keep track of original frame so we know how much it resized
	NSRect fitFrame = oldFrame;			// only set differently when sizeToFit is called, so we know it was already called
	NSRect newFrame = oldFrame;			// what we will be setting the frame to (if not already done)

//	// Try to turn on some stuff that will help me see the new bounds
//	if ([view respondsToSelector:@selector(setBordered:)]) {
//		[((NSTextField *)view) setBordered:YES];
//	}
//	if ([view respondsToSelector:@selector(setDrawsBackground:)]) {
//		[((NSTextField *)view) setDrawsBackground:YES];
//	}
//	
//	
	if ([view isKindOfClass:[NSTextField class]] &&
		[(NSTextField *)view isEditable]) {
		// Don't try to sizeToFit because edit fields really don't want to be sized
		// to what is in them as they are for users to enter things so honor their
		// current size.
	} else if ([view isKindOfClass:[NSPathControl class]]) {
		// Don't try to sizeToFit because NSPathControls usually need to be able
		// to display any path, so they shouldn't tight down to whatever they
		// happen to be listing at the moment.
	} else if ([view isKindOfClass:[NSImageView class]]) {
		// Definitely don't mess with size of an imageView
	} else if ([view isKindOfClass:[NSBox class]]) {
		// I don't think it's a good idea to let NSBox figure out its sizeToFit.
	} else if ([view isKindOfClass:[NSPopUpButton class]]) {
		// Popup buttons: Let's assume that we don't want to resize them.  Maybe later I can loop through strings
		// to get a minimum width, though some popups are designed to already be less than longest string.
		// But one thing is clear: I don't want to shrink one that is stretchy, since it's probably
		// intended to fill a space.
	} else {
		// Generically fire a sizeToFit if it has one.  e.g. NSTableColumn, NSProgressIndicator, (NSBox), NSMenuView, NSControl, NSTableView, NSText
		if ([view respondsToSelector:@selector(sizeToFit)]) {
			
			[view performSelector:@selector(sizeToFit)];
			fitFrame = [view frame];
			newFrame = fitFrame;
			
			if ([view isKindOfClass:[NSMatrix class]]) {
				NSMatrix *matrix = (NSMatrix *)view;
				// See note on kWrapperStringSlop for why this is done.
				for (NSCell *cell in [matrix cells]) {
					if ([[cell title] rangeOfString:kForcedWrapString].location !=
						NSNotFound) {
						newFrame.size.width += kWrapperStringSlop;
						break;
					}
				}
			}
			
		}
		
		// AFTER calling sizeToFit, we might override this sizing that just happened
		
		if ([view isKindOfClass:[NSButton class]]) {
			NSButton *button = (NSButton *)view;
						
			// -[NSButton sizeToFit] gives much worse results than IB's Size to Fit
			// option for standard push buttons.
			if (([button bezelStyle] == NSRoundedBezelStyle) &&
				([[button cell] controlSize] == NSRegularControlSize)) {
				// This is the amount of padding IB adds over a sizeToFit, empirically
				// determined.
				const CGFloat kExtraPaddingAmount = 12.0;
				// Width is tricky, new buttons in IB are 96 wide, Carbon seems to have
				// defaulted to 70, Cocoa seems to like 82.  But we go with 96 since
				// that's what IB is doing these days.
				const CGFloat kMinButtonWidth = (CGFloat)96.0;
				newFrame.size.width = NSWidth(newFrame) + kExtraPaddingAmount;
				if (NSWidth(newFrame) < kMinButtonWidth) {
					newFrame.size.width = kMinButtonWidth;
				}
			} else {
				// See note on kWrapperStringSlop for why this is done.
				NSString *title = [button title];
				if ([title rangeOfString:kForcedWrapString].location != NSNotFound) {
					newFrame.size.width += kWrapperStringSlop;
				}
			}
		}
	}
	
	// Now after we've tried all of this resizing, let's see if it's gotten narrower AND we wanted
	// a stretchy view.  If a view is stretchy, it means we didn't really intend on shrinking it.
	NSUInteger mask = [view autoresizingMask];
	BOOL stretchyView = 0 != (mask & NSViewWidthSizable);	// If stretchy view, DO NOT SHRINK.
	if (stretchyView && (NSWidth(newFrame) < NSWidth(oldFrame)))
	{
		newFrame = oldFrame;		// go back to the old frame; reject the size change.
	}
	
	if (!NSEqualRects(fitFrame, newFrame)) {
		[view setFrame:newFrame];
	}
	
	// Return how much we changed size.
	return NSMakeSize(NSWidth(newFrame) - NSWidth(oldFrame),
					  NSHeight(newFrame) - NSHeight(oldFrame));
}

static void OffsetView(NSView *view, NSPoint offset)
{
	NSRect newFrame = [view frame];
	newFrame.origin.x += offset.x;
	newFrame.origin.y += offset.y;
	[view setFrame:newFrame];
}

static NSString *DescViewsInRow(NSArray *sortedRowViews)
{
	NSMutableString *desc = [NSMutableString string];
	for (NSView *rowView in sortedRowViews)
	{
		NSUInteger mask = [rowView autoresizingMask];
		BOOL stretchyLeft = 0 != (mask & NSViewMinXMargin);
		BOOL stretchyView = 0 != (mask & NSViewWidthSizable);
		BOOL stretchyRight = 0 != (mask & NSViewMaxXMargin);
		
		NSString *leftMargin	= stretchyLeft	? @"···"	: @"———";
		NSString *leftWidth		= stretchyView	? @"<ɕɕ"	: @"<··";
		NSString *rightWidth	= stretchyView	? @"ɕɕ>"	: @"··>";
		NSString *rightMargin	= stretchyRight	? @"···"	: @"———";
		
		[desc appendString:leftMargin];
		[desc appendString:leftWidth];
		if ([rowView isKindOfClass:[NSTextField class]])
		{
			NSTextField *field = (NSTextField *)rowView;
			NSString *stringValue = [field stringValue];
			if ([field isEditable] || [field isBezeled] || [field isBordered])
			{
				[desc appendFormat:@"[%@           ]",stringValue];
			}
			else if ([[stringValue condenseWhiteSpace] isEqualToString:@""])
			{
				[desc appendFormat:@"\"%@\"",stringValue];
			}
			else
			{
				[desc appendString:stringValue];
			}
		}
		else if ([rowView isKindOfClass:[NSPopUpButton class]])
		{
			NSPopUpButton *pop = (NSPopUpButton *)rowView;
			NSString *selTitle = [pop titleOfSelectedItem];
			if (!selTitle || [selTitle isEqualToString:@""])
			{
				selTitle = [pop itemTitleAtIndex:0];
			}
			if (!selTitle || [selTitle isEqualToString:@""])
			{
				selTitle = @"NSPopUpButton";
			}
			
			[desc appendFormat:@"{%@}", selTitle];
		}
		else if ([rowView isKindOfClass:[NSButton class]])
		{
			NSButton *button = (NSButton *)rowView;
			NSString *title = [button title];
			
			if (!title || [title isEqualToString:@""])
			{
				title = @"NSButton";
			}
			[desc appendFormat:@"{%@}", title];
		}
		else if ([rowView isKindOfClass:[NSSlider class]])
		{
			[desc appendString:@"=======O======="];
		}
		else
		{
			//[desc appendFormat:@"<%@>",[[rowView class] description]];
			[desc appendString:[rowView description]];
		}
		[desc appendString:rightWidth];
		[desc appendString:rightMargin];
		[desc appendString:@" "];
	}
	return desc;
}

static void LogRows(NSDictionary *rows)
{
	NSArray *sortedRanges = [[rows allKeys] sortedArrayUsingSelector:@selector(compareRangeLocation:)];
	int i = 0;
	for (NSValue *rowValue in [sortedRanges reverseObjectEnumerator])
	{
		NSRange rowRange = [rowValue rangeValue];
		NSArray *subviewsOnThisRow = [rows objectForKey:rowValue];
		NSArray *sortedRowViews = [subviewsOnThisRow sortedArrayUsingSelector:@selector(compareViewFrameOriginX:)];
		NSString *desc = DescViewsInRow(sortedRowViews);
		LogIt(@"%2d. [%3d-%-3d] %@", i++, rowRange.location, NSMaxRange(rowRange), desc);
	}	
}

static NSDictionary *RowArrangeSubviews(NSView *view)
{
	NSArray *subViews = [view subviews];
	// Dictionary, where keys are NSRange/NSValues (each representing a "row" of pixels in alignment) with value being NSMutableArray (left to right?) of subviews
	NSMutableDictionary *rows = [NSMutableDictionary dictionary];
	
	for (NSView *subView in subViews)
	{
		NSRect frame = [subView frame];
		// NSLog(@"%@ -> %@", subView, NSStringFromRect(frame));
		NSRange yRange = NSMakeRange(frame.origin.y, frame.size.height);
		// Fudge just a little bit ... chop off the bottom and top 2 pixels, so that things seem less likely to intersect
		if (frame.size.height > 4)
		{
			yRange = NSMakeRange(frame.origin.y + 2, frame.size.height - 4);
		}
		
		// Now see if this range intersects one of our index sets
		BOOL found = NO;
		for (NSValue *rowValue in [rows allKeys])
		{
			NSRange rowRange = [rowValue rangeValue];
			if (NSIntersectionRange(rowRange, yRange).length)
			{
				// Add this subView to the list for this row
				NSMutableArray *rowArray = [rows objectForKey:rowValue];
				[rowArray addObject:subView];
				
				// Extend the row range if needed, and modify dictionary if it changed
				NSRange newRowRange = NSUnionRange(rowRange, yRange);
				if (!NSEqualRanges(newRowRange, rowRange))
				{
					[rows setObject:rowArray forKey:[NSValue valueWithRange:newRowRange]];
					[rows removeObjectForKey:rowValue];
				}
				found = YES;
				break;  // found, so no need to keep looking
			}
		}
		if (!found)	// not found, make a new row entry
		{
			[rows setObject:[NSMutableArray arrayWithObject:subView] forKey:[NSValue valueWithRange:yRange]];
		}
	}
	return [NSDictionary dictionaryWithDictionary:rows];
}


static CGFloat TweakLayoutForView(NSView *encView, NSArray *rowViews, NSPoint offset, NSUInteger level)
{
	NSString *desc = DescViewsInRow(rowViews);
	LogIt(@"%@%@", [@"                                                            " substringToIndex:2*level], desc);
	
	CGFloat widthChange_ = 0.0;
	
	if (![rowViews count]) {
		widthChange_ = 0.0;
		return widthChange_;
	}
	
	NSMutableArray *rightAlignedSubViews = nil;
	NSMutableArray *rightAlignedSubViewDeltas = nil;
	
	rightAlignedSubViews = [NSMutableArray array];
	rightAlignedSubViewDeltas = [NSMutableArray array];
	
	// Size our rowViews
	
	NSView *subView = nil;
	CGFloat finalDelta = 0;
	NSPoint subViewOffset = NSZeroPoint;
	for (subView in rowViews) {
		
		subViewOffset.x = finalDelta;	// we'll be moving it over by the so-far delta
		
		CGFloat thisDelta = ResizeToFit(subView).width;
		if (0 != thisDelta)		// no point in looking if nothing changed
		{
			finalDelta += thisDelta;
			
			// Track the right anchored rowViews size changes so we can update them
			// once we know this view's size.
			if (IsRightAnchored(subView)) {
				[rightAlignedSubViews addObject:subView];
				NSNumber *nsDelta = [NSNumber numberWithFloat:thisDelta];
				[rightAlignedSubViewDeltas addObject:nsDelta];
			}
		}
	}
	
	
	// Now spin over the list of right aligned view and their size changes
	// fixing up their positions so they are still right aligned in our final
	// view.
	for (NSUInteger lp = 0; lp < [rightAlignedSubViews count]; ++lp) {
		subView = [rightAlignedSubViews objectAtIndex:lp];
		CGFloat delta = [[rightAlignedSubViewDeltas objectAtIndex:lp] doubleValue];
		NSRect viewFrame = [subView frame];
		viewFrame.origin.x += -delta + finalDelta;
		[subView setFrame:viewFrame];
	}
	/*
	 if (viewToSlideAndResize_) {
	 NSRect viewFrame = [viewToSlideAndResize_ frame];
	 if (!rightAnchored) {
	 // If our right wasn't anchored, this view slides (we push it right).
	 // (If our right was anchored, the assumption is the view is in front of
	 // us so its x shouldn't move.)
	 viewFrame.origin.x += finalDelta;
	 }
	 viewFrame.size.width -= finalDelta;
	 [viewToSlideAndResize_ setFrame:viewFrame];
	 }
	 if (viewToSlide_) {
	 NSRect viewFrame = [viewToSlide_ frame];
	 // Move the view the same direction we moved.
	 if (rightAnchored) {
	 viewFrame.origin.x -= finalDelta;
	 } else {
	 viewFrame.origin.x += finalDelta;
	 }
	 [viewToSlide_ setFrame:viewFrame];
	 }
	 if (viewToResize_) {
	 if ([viewToResize_ isKindOfClass:[NSWindow class]]) {
	 NSWindow *window = (NSWindow *)viewToResize_;
	 NSView *contentView = [window contentView];
	 NSRect windowFrame = [contentView convertRect:[window frame]
	 fromView:nil];
	 windowFrame.size.width += finalDelta;
	 windowFrame = [contentView convertRect:windowFrame toView:nil];
	 [window setFrame:windowFrame display:YES];
	 // For some reason the content view is resizing, but not adjusting its
	 // origin, so correct it manually.
	 [contentView setFrameOrigin:NSMakePoint(0, 0)];
	 // TODO: should we update min size?
	 } else {
	 NSRect viewFrame = [viewToResize_ frame];
	 viewFrame.size.width += finalDelta;
	 [viewToResize_ setFrame:viewFrame];
	 // TODO: should we check if this view is right anchored, and adjust its
	 // x position also?
	 }
	 }
	 */
	widthChange_ = finalDelta;
	return widthChange_;
}



static void ResizeView(NSView *view, NSUInteger level)
{
	if ([[view subviews] count])
	{
		// First handle the sub-views, so we are going OUT
		if ([view isKindOfClass:[NSTabView class]])
		{
			NSArray *tabViewItems = [(NSTabView *)view tabViewItems];
			for (NSTabViewItem *item in tabViewItems)		// resize tabviews instead of subviews
			{
				ResizeView([item view], level+1);
			}
		}
		else
		{
			for (NSView *subview in [view subviews])
			{
				ResizeView(subview, level+1);
			}
		}
		
		
		
		NSDictionary *rows = RowArrangeSubviews(view);
		
		LogRows(rows);
		
		NSArray *sortedRanges = [[rows allKeys] sortedArrayUsingSelector:@selector(compareRangeLocation:)];
		CGFloat largestDelta = 0;
		for (NSValue *rowValue in [sortedRanges reverseObjectEnumerator])
		{
			NSArray *subviewsOnThisRow = [rows objectForKey:rowValue];
			NSArray *sortedRowViews = [subviewsOnThisRow sortedArrayUsingSelector:@selector(compareViewFrameOriginX:)];
			
			CGFloat delta = TweakLayoutForView(view, sortedRowViews, NSZeroPoint, level);
			// NSLog(@"Offset for this row: %.2f", offset);
			largestDelta = MAX(largestDelta,delta);		// pay attention to the largest amount we had to resize things
		}
		
		if (largestDelta)
		{
			LogIt(@"%@%@ Largest Offset for this whole view: %.2f", [@"                                                            " substringToIndex:2*level], view, largestDelta);
			
			// Are we pinned to the right of our parent?
			BOOL rightAnchored = IsRightAnchored(view);
			
			// Adjust our size (turn off auto resize, because we just fixed up all the
			// objects within us).
			BOOL autoresizesSubviews = [view autoresizesSubviews];
			if (autoresizesSubviews) {
				[view setAutoresizesSubviews:NO];
			}
			NSRect selfFrame = [view frame];
			selfFrame.size.width += largestDelta;
			if (rightAnchored) {
				// Right side is anchored, so we need to slide back to the left.
				selfFrame.origin.x -= largestDelta;
			}
			//	selfFrame.origin.x += offset.x;
			//	selfFrame.origin.y += offset.y;
			[view setFrame:selfFrame];
			if (autoresizesSubviews) {
				[view setAutoresizesSubviews:autoresizesSubviews];
			}
		}
		
		
		//LogIt(@"%@%@", [@"                                                            " substringToIndex:2*level], [[view description] condenseWhiteSpace]);
		
		
	}
}















// ===========================================================================











@interface NSValue (comparison)

- (NSComparisonResult)compareRangeLocation:(NSValue *)otherRangeValue;

@end

@implementation NSValue (comparison)

- (NSComparisonResult)compareRangeLocation:(NSValue *)otherRangeValue;
{
	NSUInteger location = [self rangeValue].location;
	NSUInteger otherLocation = [otherRangeValue rangeValue].location;
	
	if (location == otherLocation) return NSOrderedSame;
    else if (location > otherLocation) return NSOrderedDescending;
    else return NSOrderedAscending;
}

@end

@interface NSView (comparison)

- (NSComparisonResult)compareViewFrameOriginX:(NSView *)otherView;

@end

@implementation NSView (comparison)

- (NSComparisonResult)compareViewFrameOriginX:(NSView *)otherView;
{
	CGFloat originX = [self frame].origin.x;
	CGFloat otherOriginX = [otherView frame].origin.x;
	
	if (originX == otherOriginX) return NSOrderedSame;
    else if (originX > otherOriginX) return NSOrderedDescending;
    else return NSOrderedAscending;
}

@end




@interface NSBundle (DMLocalizedNibBundle)
+ (BOOL)deliciousLocalizingLoadNibFile:(NSString *)fileName externalNameTable:(NSDictionary *)context withZone:(NSZone *)zone;
@end


// Try to swizzle in -[NSViewController loadView]

@interface NSViewController (DMLocalizedNibBundle)
- (void)deliciousLocalizingLoadView;
@end






@interface NSBundle ()
+ (BOOL)_deliciousLocalizingLoadNibFile:(NSString *)fileName externalNameTable:(NSDictionary *)context withZone:(NSZone *)zone bundle:(NSBundle *)aBundle;

+ (NSString *)	 _localizedStringForString:(NSString *)string bundle:(NSBundle *)bundle table:(NSString *)table;
+ (void)				  _localizeStringsInObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table level:(NSUInteger)level;
// localize particular attributes in objects
+ (void)					_localizeTitleOfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table level:(NSUInteger)level;
+ (void)		   _localizeAlternateTitleOfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table level:(NSUInteger)level;
+ (void)			  _localizeStringValueOfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table level:(NSUInteger)level;
+ (void)		_localizePlaceholderStringOfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table level:(NSUInteger)level;
+ (void)				  _localizeToolTipOfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table level:(NSUInteger)level;
+ (void)				    _localizeLabelOfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table level:(NSUInteger)level;
+ (void)			 _localizePaletteLabelOfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table level:(NSUInteger)level;


@end

@implementation NSViewController (DMLocalizedNibBundle)

+ (void)load;
{
    NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
    if (
		
		([NSUserName() isEqualToString:DEBUG_THIS_USER]) &&
		
		self == [NSViewController class]) {
		NSLog(@"Switching in NSViewController Localizer!");
        method_exchangeImplementations(class_getInstanceMethod(self, @selector(loadView)), class_getInstanceMethod(self, @selector(deliciousLocalizingLoadView)));
    }
    [autoreleasePool release];
}


- (void)deliciousLocalizingLoadView
{
	NSString		*nibName	= [self nibName];
	NSBundle		*nibBundle	= [self nibBundle];		
	// NSLog(@"%s %@ %@",__FUNCTION__, nibName, nibBundle);
	if(!nibBundle) nibBundle = [NSBundle mainBundle];
	NSString		*nibPath	= [nibBundle pathForResource:nibName ofType:@"nib"];
	NSDictionary	*context	= [NSDictionary dictionaryWithObjectsAndKeys:self, NSNibOwner, nil];
	
	NSLog(@"loadView %@ going to localize %@ with top objects: %@", [[nibBundle bundlePath] lastPathComponent], [nibPath lastPathComponent], [[context description] condenseWhiteSpace]);
	BOOL loaded = [NSBundle _deliciousLocalizingLoadNibFile:nibPath externalNameTable:context withZone:nil bundle:nibBundle];	// call through to support method
	if (!loaded)
	{
		[NSBundle deliciousLocalizingLoadNibFile:nibPath externalNameTable:context withZone:nil];	// use old-fashioned way
	}
}

@end


@implementation NSBundle (DMLocalizedNibBundle)

+ (void)load;
{
    NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
    if (
		
		([NSUserName() isEqualToString:DEBUG_THIS_USER]) &&
		
		self == [NSBundle class]) {
		NSLog(@"Switching in NSBundle localizer. W00T!");
        method_exchangeImplementations(class_getClassMethod(self, @selector(loadNibFile:externalNameTable:withZone:)), class_getClassMethod(self, @selector(deliciousLocalizingLoadNibFile:externalNameTable:withZone:)));
    }
    [autoreleasePool release];
}

// Method that gets swapped
+ (BOOL)deliciousLocalizingLoadNibFile:(NSString *)fileName externalNameTable:(NSDictionary *)context withZone:(NSZone *)zone;
{
	BOOL result = NO;
	// Don't allow this to localize any file that is not in the app bundle!
	if ([fileName hasPrefix:[[NSBundle mainBundle] bundlePath]])
	{
		NSLog(@"loadNibFile going to localize %@ with top objects: %@", [fileName lastPathComponent], [[context description] condenseWhiteSpace]);
		result = [self _deliciousLocalizingLoadNibFile:fileName externalNameTable:context withZone:zone bundle:[NSBundle mainBundle]];
	}
	else
	{
		NSLog(@"%s is NOT LOCALIZING non-app loadNibFile:%@",__FUNCTION__, fileName);
	}
	if (!result)
	{
		// try original version
		result = [self deliciousLocalizingLoadNibFile:fileName externalNameTable:context withZone:zone];
	}
	return result;
}





#pragma mark Private API


/*
 
 Aspects of a nib still to do:
	NSTableView
	AXDescription and AXRole
	
 Others?
 
 Next up: stretching items....
 
 
 */


// Internal method, which gets an extra parameter for bundle
+ (BOOL)_deliciousLocalizingLoadNibFile:(NSString *)fileName externalNameTable:(NSDictionary *)context withZone:(NSZone *)zone bundle:(NSBundle *)aBundle;
{
	//NSLog(@"%s %@",__FUNCTION__, fileName);
	
	// Note: What about loading not from the main bundle? Can I try to load from where the nib file came from?
	
    NSString *localizedStringsTableName = [[fileName lastPathComponent] stringByDeletingPathExtension];
    NSString *localizedStringsTablePath = [[NSBundle mainBundle] pathForResource:localizedStringsTableName ofType:@"strings"];
    if (
		
		([NSUserName() isEqualToString:@"dwood"]) || 
		
		localizedStringsTablePath
		&& ![[[localizedStringsTablePath stringByDeletingLastPathComponent] lastPathComponent] isEqualToString:@"English.lproj"]
		&& ![[[localizedStringsTablePath stringByDeletingLastPathComponent] lastPathComponent] isEqualToString:@"en.lproj"]
		)
	{
        NSNib *nib = [[NSNib alloc] initWithContentsOfURL:[NSURL fileURLWithPath:fileName]];
        NSMutableArray *topLevelObjectsArray = [context objectForKey:NSNibTopLevelObjects];
        if (!topLevelObjectsArray) {
            topLevelObjectsArray = [NSMutableArray array];
            context = [NSMutableDictionary dictionaryWithDictionary:context];
            [(NSMutableDictionary *)context setObject:topLevelObjectsArray forKey:NSNibTopLevelObjects];
        }
		
		// Note: This will call awakeFromNib so you want to make sure not to load a new nib *from*
		// awakeFromNib that inserts something into the view hiearchy, or you may have double-
		// localization happening.
        BOOL success = [nib instantiateNibWithExternalNameTable:context];
		
        [self _localizeStringsInObject:topLevelObjectsArray bundle:aBundle table:localizedStringsTableName level:0];
		
		for (id topLevelObject in topLevelObjectsArray)
		{
			if ([topLevelObject isKindOfClass:[NSView class]])
			{
				NSView *view = (NSView *)topLevelObject;
				
				if ([fileName hasSuffix:@"DocumentInspector.nib"])
				{
					ResizeView(view, 0);
				}
			}
			else if ([topLevelObject isKindOfClass:[NSWindow class]])
			{
				NSWindow *window = (NSWindow *)topLevelObject;
				
				// Here, I think, I probably want to do some sort of call to the NSWindow delegate to ask
				// what width it would like to be for various languages, so I can make the inspector window wider for French/German.
				// That would keep it generic here.
				
				// HACK for now to make the inspector window wider.
				if ([fileName hasSuffix:@"KSInspector.nib"])
				{
					NSView *contentView = [window contentView];
					NSRect windowFrame = [contentView convertRect:[window frame]
														 fromView:nil];
					windowFrame.size.width += 100;
					windowFrame = [contentView convertRect:windowFrame toView:nil];
					[window setFrame:windowFrame display:YES];	
					
					// TODO: should we update min size?
					
					ResizeView([window contentView], 0);
					
				}
				
			}
		}
        
        [nib release];
        return success;
        
    } else {
		
        if (nil == localizedStringsTablePath)
		{
			NSLog(@"Not running through localizer because localizedStringsTablePath == nil");
		}
		else
		{
			NSLog(@"Not running through localizer because containing dir is not English: %@", [[localizedStringsTablePath stringByDeletingLastPathComponent] lastPathComponent]);
		}
		
		return NO;		// not successful
    }
}

+ (void)_localizeAccessibility:(id)object bundle:(NSBundle *)bundle table:(NSString *)table level:(NSUInteger)level;
{
	// Hack -- don't localize accessibility properties of cells, since the AXHelp of a cell is copied from the tooltip of its enclosing button.
	if ([object isKindOfClass:[NSCell class]]) return;
	
	NSArray *supportedAttrs = [object accessibilityAttributeNames];
	if ([supportedAttrs containsObject:NSAccessibilityHelpAttribute]) {
		NSString *accessibilityHelp
		= [object accessibilityAttributeValue:NSAccessibilityHelpAttribute];
		if (accessibilityHelp) {
			
			NSString *toolTip = nil;		// get the tooltip and make sure it's not the same; Help seems to come from tooltip if undefined!
			if ([object respondsToSelector:@selector(toolTip)]) toolTip = [object toolTip];
			if (![accessibilityHelp isEqualToString:toolTip])
			{
				NSString *localizedAccessibilityHelp
				= [self _localizedStringForString:accessibilityHelp bundle:bundle table:table];
				if (localizedAccessibilityHelp) {
					
					if ([object accessibilityIsAttributeSettable:NSAccessibilityHelpAttribute])
					{
						NSLog(@"ACCESSIBILITY: %@ %@", localizedAccessibilityHelp, localizedAccessibilityHelp);
						[object accessibilitySetValue:localizedAccessibilityHelp
										 forAttribute:NSAccessibilityHelpAttribute];
					}
					else
					{
						NSLog(@"DISALLOWED ACCESSIBILITY: %@ %@", localizedAccessibilityHelp, localizedAccessibilityHelp);
						
					}
				}
			}
		}
	}
}


//
// NOT SURE:
// Should we localize NSWindowController's window and NSViewController's view? Probably not; they would be top-level objects in nib.
// Or NSApplication's main menu? Probably same thing.


+ (void)_localizeStringsInObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table level:(NSUInteger)level;
{
	if (!object) return;
	// if ([object isKindOfClass:[NSArray class]] && 0 == [object count]) return;		// SHORT CIRCUIT SO WE DON'T SEE LOGGING
	// LogIt(@"%@%@", [@"                                                            " substringToIndex:2*level], [[object description] condenseWhiteSpace]);
	level++;	// recursion will incrememnt
	// NSArray ... this is not directly in the nib, but for when we recurse.
	
    if ([object isKindOfClass:[NSArray class]]) {
        NSArray *array = object;
        
        for (id nibItem in array)
            [self _localizeStringsInObject:nibItem bundle:bundle table:table level:level];
	
	// NSCell & subclasses
		
    } else if ([object isKindOfClass:[NSCell class]]) {
        NSCell *cell = object;
        
        if ([cell isKindOfClass:[NSActionCell class]]) {
            NSActionCell *actionCell = (NSActionCell *)cell;
            
            if ([actionCell isKindOfClass:[NSButtonCell class]]) {
                NSButtonCell *buttonCell = (NSButtonCell *)actionCell;
                if ([buttonCell imagePosition] != NSImageOnly) {
                    [self _localizeTitleOfObject:buttonCell bundle:bundle table:table level:level];
                    [self _localizeStringValueOfObject:buttonCell bundle:bundle table:table level:level];
                    [self _localizeAlternateTitleOfObject:buttonCell bundle:bundle table:table level:level];
                }
                
            } else if ([actionCell isKindOfClass:[NSTextFieldCell class]]) {
                NSTextFieldCell *textFieldCell = (NSTextFieldCell *)actionCell;
                // Following line is redundant with other code, localizes twice.
                // [self _localizeTitleOfObject:textFieldCell bundle:bundle table:table level:level];
                [self _localizeStringValueOfObject:textFieldCell bundle:bundle table:table level:level];
                [self _localizePlaceholderStringOfObject:textFieldCell bundle:bundle table:table level:level];
                
            } else if ([actionCell type] == NSTextCellType) {
                [self _localizeTitleOfObject:actionCell bundle:bundle table:table level:level];
                [self _localizeStringValueOfObject:actionCell bundle:bundle table:table level:level];
            }
        }
        
	// NSToolbar
		
    } else if ([object isKindOfClass:[NSToolbar class]]) {
        NSToolbar *toolbar = object;
		NSArray *items = [toolbar items];
		for (NSToolbarItem *item in items)
		{
			[self _localizeLabelOfObject:item bundle:bundle table:table level:level];
			[self _localizePaletteLabelOfObject:item bundle:bundle table:table level:level];
			[self _localizeToolTipOfObject:item bundle:bundle table:table level:level];
		}
		
	// NSMenu
		
    } else if ([object isKindOfClass:[NSMenu class]]) {
        NSMenu *menu = object;
				
        [self _localizeTitleOfObject:menu bundle:bundle table:table level:level];
        
        [self _localizeStringsInObject:[menu itemArray] bundle:bundle table:table level:level];
        
	// NSMenuItem
		
    } else if ([object isKindOfClass:[NSMenuItem class]]) {
        NSMenuItem *menuItem = object;

		[self _localizeTitleOfObject:menuItem bundle:bundle table:table level:level];
        
        [self _localizeStringsInObject:[menuItem submenu] bundle:bundle table:table level:level];
        
	// NSView + subclasses
				
    } else if ([object isKindOfClass:[NSView class]]) {
        NSView *view = object;        
		[self _localizeAccessibility:view bundle:bundle table:table level:level];
		// Do tooltip AFTER AX since AX might just get value from tooltip. 
        [self _localizeToolTipOfObject:view bundle:bundle table:table level:level];

		// Contextual menu?  Anything else besides a popup button
		// I am NOT going to localize this, because it seems to be automatically generated, and there
		// tends to be multiple copies instantiated.  Since it's not instantiated in the nib (except perhaps
		// as a top-level object) I don't want to localize it.
		// Note: If I do, I have to be sure to not also localize a NSPopUpButton's menu, which uses the menu accessor.
		//[self _localizeStringsInObject:[view menu] bundle:bundle table:table level:level];
		
		// NSTableView
		
		if ([object isKindOfClass:[NSTableView class]]) {
			NSTableView *tableView = (NSTableView *)object;
			NSArray *columns = [tableView tableColumns];
			for (NSTableColumn *column in columns)
			{
				[self _localizeStringValueOfObject:[column headerCell] bundle:bundle table:table level:level];
			}

		// NSBox
		
		} else if ([view isKindOfClass:[NSBox class]]) {
            NSBox *box = (NSBox *)view;
            [self _localizeTitleOfObject:box bundle:bundle table:table level:level];
           
		// NSTabView
			
        } else if ([view isKindOfClass:[NSTabView class]]) {
            NSTabView *tabView = (NSTabView *)view;
			NSArray *tabViewItems = [tabView tabViewItems];
		
			for (NSTabViewItem *item in tabViewItems)
			{
				[self _localizeLabelOfObject:item bundle:bundle table:table level:level];
				
				NSView *viewToLocalize = [item view];
				if (![[view subviews] containsObject:viewToLocalize])	// don't localize one that is current subview
				{
					[self _localizeStringsInObject:viewToLocalize bundle:bundle table:table level:level];
				}
			}
		
		// NSControl + subclasses
			
        } else if ([view isKindOfClass:[NSControl class]]) {
            NSControl *control = (NSControl *)view;
            
			[self _localizeAccessibility:[control cell] bundle:bundle table:table level:level];

			
			// NSButton
			
            if ([view isKindOfClass:[NSButton class]]) {
                NSButton *button = (NSButton *)control;
                
                if ([button isKindOfClass:[NSPopUpButton class]]) {
					// Note: Be careful not to localize this *and* the menu for an NSView. 
                    NSPopUpButton *popUpButton = (NSPopUpButton *)button;
                    NSMenu *menu = [popUpButton menu];
                    
                    [self _localizeStringsInObject:[menu itemArray] bundle:bundle table:table level:level];
                } else
                    [self _localizeStringsInObject:[button cell] bundle:bundle table:table level:level];
                
			
			// NSMatrix
				
            } else if ([view isKindOfClass:[NSMatrix class]]) {
                NSMatrix *matrix = (NSMatrix *)control;
                
                NSArray *cells = [matrix cells];
                [self _localizeStringsInObject:cells bundle:bundle table:table level:level];
                
                for (NSCell *cell in cells) {
                    
                    NSString *localizedCellToolTip = [self _localizedStringForString:[matrix toolTipForCell:cell] bundle:bundle table:table];
                    if (localizedCellToolTip)
                        [matrix setToolTip:localizedCellToolTip forCell:cell];
                }
              
			// NSSegmentedControl
				
            } else if ([view isKindOfClass:[NSSegmentedControl class]]) {
                NSSegmentedControl *segmentedControl = (NSSegmentedControl *)control;
                
                NSUInteger segmentIndex, segmentCount = [segmentedControl segmentCount];
                for (segmentIndex = 0; segmentIndex < segmentCount; segmentIndex++) {
                    NSString *localizedSegmentLabel = [self _localizedStringForString:[segmentedControl labelForSegment:segmentIndex] bundle:bundle table:table];
                    if (localizedSegmentLabel)
                        [segmentedControl setLabel:localizedSegmentLabel forSegment:segmentIndex];
                    
                    [self _localizeStringsInObject:[segmentedControl menuForSegment:segmentIndex] bundle:bundle table:table level:level];
                }
             
			// OTHER ... e.g. NSTextField NSSlider NSScroller NSImageView 
				
            } else
			{
                [self _localizeStringsInObject:[control cell] bundle:bundle table:table level:level];
			}
			
        }
        
		// Then localize this view's subviews
		
        [self _localizeStringsInObject:[view subviews] bundle:bundle table:table level:level];
			       
	// NSWindow
		
    } else if ([object isKindOfClass:[NSWindow class]]) {
        NSWindow *window = object;
        [self _localizeTitleOfObject:window bundle:bundle table:table level:level];
        
        [self _localizeStringsInObject:[window contentView] bundle:bundle table:table level:level];
		[self _localizeStringsInObject:[window toolbar] bundle:bundle table:table level:level];

    }
	
	// Finally, bindings.  Basically lifted from the Google Toolkit.
	NSArray *exposedBindings = [object exposedBindings];
	if (exposedBindings) {
		NSString *optionsToLocalize[] = {
			NSDisplayNameBindingOption,
			NSDisplayPatternBindingOption,
			NSMultipleValuesPlaceholderBindingOption,
			NSNoSelectionPlaceholderBindingOption,
			NSNotApplicablePlaceholderBindingOption,
			NSNullPlaceholderBindingOption,
		};
		for (NSString *exposedBinding in exposedBindings)
		{
			NSDictionary *bindingInfo = [object infoForBinding:exposedBinding];
			if (bindingInfo) {
				id observedObject = [bindingInfo objectForKey:NSObservedObjectKey];
				NSString *path = [bindingInfo objectForKey:NSObservedKeyPathKey];
				NSDictionary *options = [bindingInfo objectForKey:NSOptionsKey];
				if (observedObject && path && options) {
					NSMutableDictionary *newOptions 
					= [NSMutableDictionary dictionaryWithDictionary:options];
					BOOL valueChanged = NO;
					for (size_t i = 0; 
						 i < sizeof(optionsToLocalize) / sizeof(optionsToLocalize[0]);
						 ++i) {
						NSString *key = optionsToLocalize[i];
						NSString *value = [newOptions objectForKey:key];
						if ([value isKindOfClass:[NSString class]]) {
							NSString *localizedValue = [self _localizedStringForString:value bundle:bundle table:table];
							if (localizedValue) {
								valueChanged = YES;
								[newOptions setObject:localizedValue forKey:key];
							}
						}
					}
					if (valueChanged) {
						// Only unbind and rebind if there is a change.
						[object unbind:exposedBinding];
						[object bind:exposedBinding 
							toObject:observedObject 
						 withKeyPath:path 
							 options:newOptions];
					}
				}
			}
		}
	}
	
	
}



+ (NSString *)_localizedStringForString:(NSString *)string bundle:(NSBundle *)bundle table:(NSString *)table;
{
    if (![string length])
        return nil;
    
	if ([string hasPrefix:@"["])
	{
		NSLog(@"??? Double-translation of %@", string);
	}
    static NSString *defaultValue = @"I AM THE DEFAULT VALUE";
    NSString *localizedString = [bundle localizedStringForKey:string value:defaultValue table:table];
    if (![localizedString isEqualToString:defaultValue]) {
        return [NSString stringWithFormat:@"[_%@_]", localizedString];
    } else { 
#ifdef DEBUG
 //       NSLog(@"        Can't find translation for string %@", string);
       return [NSString stringWithFormat:@"[%@]", [string uppercaseString]];
       // return string;
#else
        return string;
#endif
    }
}


#define DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(blahName, capitalizedBlahName) \
+ (void)_localize ##capitalizedBlahName ##OfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table level:(NSUInteger)level; \
{ \
NSString *localizedBlah = [self _localizedStringForString:[object blahName] bundle:bundle table:table]; \
if (localizedBlah) \
[object set ##capitalizedBlahName:localizedBlah]; \
}

DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(title, Title)
DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(alternateTitle, AlternateTitle)
DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(stringValue, StringValue)
DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(placeholderString, PlaceholderString)
DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(toolTip, ToolTip)
DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(label, Label)
DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(paletteLabel, PaletteLabel)

@end
