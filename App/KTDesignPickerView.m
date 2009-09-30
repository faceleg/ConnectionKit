//
//  KTDesignPickerView.m
//  Marvel
//
//  Created by Dan Wood on 7/20/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "KTDesignPickerView.h"

#import "KTDocWindowController.h"
#import "KTAppDelegate.h"
#import "KTDesign.h"
#import "KTDocWindowController.h"
#import "KTDocument.h"
#import "KTMaster.h"

#import "CIImage+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSImage+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSWorkspace+Karelia.h"

#import <QuartzCore/QuartzCore.h>
#import <ScreenSaver/ScreenSaver.h>


enum { NO_ANIMATION, ANIMATION, FAST_ANIMATION };


// TODO: .. I REALLY NEED THE CONCEPT OF FOCUS HERE, TOO.  BE ABLE TO USE ARROW KEYS TO CHANGE DESIGN, ETC.

#define TRANSITION_DURATION_PER			0.1
#define TRANSITION_SLOWMO_DURATION_PER  0.6
#define TRANSITION_FAST_DURATION_PER	0.05

// Pixels from the bottom left to show the overlay images
#define kBottomMargin 3
#define kLeftMargin 0

// Relative to above, where to show the thumbnails
#define kYThumbPosition 18
#define kXThumbPosition 12

// Y position, relative from bottom margin, to show text.  (X is calculated)
#define kYTextPosition -1

// Thumbnail image size
#define kThumbnailWidth 100
#define kThumbnailHeight 65

// Size of overlay elements (frames, gloss, etc)  [no space between overlays, BTW]
#define kOverlayWidth 124
#define kOverlayHeight 101

// Left/right margin from edges
#define kTextMargin 6

// How many pixels from right side to draw the gradient cover
#define kCoverXPosition 10

// How many pixels we need to consider that we are showing an additional partial design
#define kMinimumPartialWidth 16

static NSImage *sDesignCoverRight = nil;
static NSImage *sDesignCoverRightSearch = nil;
static NSImage *sDesignCoverLeft = nil;
static NSImage *sDesignCoverLeftSearch = nil;
static NSImage *sDesignClickGloss = nil;
static NSImage *sDesignSelectedClickGloss = nil;
static NSImage *sDesignHover = nil;
static NSImage *sDesignMask = nil;
static NSImage *sDesignNormalFrame = nil;
static NSImage *sDesignNormalGloss = nil;
static NSImage *sDesignSelectedFrame = nil;
static NSImage *sDesignSelectedGloss = nil;	
static NSImage *sUnknownThumbnail = nil;

static NSDictionary *sAttributes = nil;
static NSDictionary *sContributorAttributes = nil;
static NSDictionary *sContributorLinkAttributes = nil;

@interface NSAffineTransform ( Shear )

- (void) shearXBy: (float) xShear yBy: (float) yShear;
- (void) shearXBy:(float) xShear;
- (void) shearYBy:(float) yShear;

@end

@implementation NSAffineTransform (Shearing)

// from http://developer.apple.com/qa/qa2001/qa1332.html

- (void) shearXBy: (float) xShear yBy: (float) yShear;
{
	NSAffineTransform *shearTransform = [[NSAffineTransform alloc] init];
	NSAffineTransformStruct transformStruct = [shearTransform transformStruct];
	
	transformStruct.m21 = xShear;
	transformStruct.m12 = yShear;
	
	[shearTransform setTransformStruct:transformStruct];
	[self appendTransform:shearTransform];
	[shearTransform release];
}

- (void) shearXBy:(float) xShear { [self shearXBy:xShear yBy:0.0];  }
- (void) shearYBy:(float) yShear  {  [self shearXBy:0.0 yBy:yShear]; }

@end

@interface DesignPickerAnimation : NSAnimation
@end

@implementation DesignPickerAnimation

// Override NSAnimation's -setCurrentProgress: method, and use it as our point to hook in and advance our Core Image transition effect to the next time slice.
- (void)setCurrentProgress:(NSAnimationProgress)progress {
    // First, invoke super's implementation, so that the NSAnimation will remember the proposed progress value and hand it back to us when we ask for it in AnimatingTabView's -drawRect: method.
    [super setCurrentProgress:progress];
	
    // Now ask the AnimatingTabView (which set itself as our delegate) to display.  Sending a -display message differs from sending -setNeedsDisplay: or -setNeedsDisplayInRect: in that it demands an immediate, syncrhonous redraw of the view.  Most of the time, it's preferrable to send a -setNeedsDisplay... message, which gives AppKit the opportunity to coalesce potentially numerous display requests and update the window efficiently when it's convenient.  But for a syncrhonously executing animation, it's appropriate to use -display.
    [((NSView *)[self delegate]) display];
}

@end

@interface KTDesignPickerView ()
- (void)moveToNewPosition:(int)aNewPosition animationType:(int)animationType;
- (void)clearTrackingRects;
@end


#pragma mark -


@implementation KTDesignPickerView

+ (void) initialize
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	sDesignCoverLeft = [[NSImage imageNamed:@"designCoverLeft"] retain];
	sDesignCoverLeftSearch = [[NSImage imageNamed:@"designCoverLeftSearch"] retain];
	sDesignCoverRight = [[NSImage imageNamed:@"designCoverRight"] retain];
	sDesignCoverRightSearch = [[NSImage imageNamed:@"designCoverRightSearch"] retain];
	sDesignClickGloss = [[NSImage imageNamed:@"designClickGloss"] retain];
	sDesignSelectedClickGloss = [[NSImage imageNamed:@"designSelectedClickGloss"] retain];
	sDesignHover = [[NSImage imageNamed:@"designHover"] retain];
	sDesignMask = [[NSImage imageNamed:@"designMask"] retain];
	sDesignNormalFrame = [[NSImage imageNamed:@"designNormalFrame"] retain];
	sDesignNormalGloss = [[NSImage imageNamed:@"designNormalGloss"] retain];
	sDesignSelectedFrame = [[NSImage imageNamed:@"designSelectedFrame"] retain];
	sDesignSelectedGloss = [[NSImage imageNamed:@"designSelectedGloss"] retain];
	sUnknownThumbnail = [[[NSImage imageNamed:@"qmark"] imageWithMaxWidth:kThumbnailWidth height:kThumbnailHeight] retain];
	
	sAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:
		[NSFont systemFontOfSize:[NSFont smallSystemFontSize]], NSFontAttributeName,
		nil];
	
	// Contribuotor -- gray/blue.
	sContributorAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:
		[NSFont systemFontOfSize:[NSFont smallSystemFontSize]], NSFontAttributeName,
		[NSColor colorWithCalibratedRed:0.3 green:0.3 blue:0.5 alpha:1.0], NSForegroundColorAttributeName,
		nil];
	
	// Hyperlinks -- slightly bluer, with an underline
	sContributorLinkAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:
		[NSFont systemFontOfSize:[NSFont smallSystemFontSize]], NSFontAttributeName,
		[NSColor colorWithCalibratedRed:0.2 green:0.3 blue:0.6 alpha:1.0], NSForegroundColorAttributeName,
		[NSNumber numberWithInt:1], NSUnderlineStyleAttributeName,
		[NSCursor pointingHandCursor], NSCursorAttributeName,
		// [NSColor colorWithCalibratedRed:0.2 green:0.3 blue:0.6 alpha:1.0], NSUnderlineColorAttributeName,
		nil];
	[pool release];
	
	
	// Bindings
	[self exposeBinding:@"selectedDesign"];
}

- (void)dealloc
{
	[self clearTrackingRects];
	[myDesign release];

	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

- (NSArray *)designsToShow
{
	return [KSPlugin sortedPluginsWithFileExtension:kKTDesignExtension];	// all visible designs
}

- (int) totalDesignCount
{
	return [[self designsToShow] count];	// all visible designs
}

#pragma mark -
#pragma mark Selection

/*	Support method when chaning selection.
 */
- (void)setCurrentSelectionToIdentifier:(NSString *)identifier;
{
	NSEnumerator *theEnum = [[self designsToShow] objectEnumerator];
	KTDesign *design;
	int count = 0;
	
	
	while (nil != (design = [theEnum nextObject]) )
	{
		if ([[design identifier] isEqualToString:identifier])
		{
			BOOL reopening = (mySelectedIndex >= 0);
			mySelectedIndex = count;
			
			// Now figure out if we need to adjust the position
			if (mySelectedIndex < myListOffset || mySelectedIndex >= (myListOffset + myNumberOfDesignsCompletelyVisible) )
			{
				// scroll to show our item at left, or over to the right more if we
				// are near the end of the list
				int theMin = MIN(mySelectedIndex, [self totalDesignCount] - myNumberOfDesignsCompletelyVisible);
				int newPosition = MAX(0, theMin);
				if (reopening)
				{
					// animate to the new position, but only after all this is done.
					[self performSelector:@selector(fastAnimateToNewPosition:) withObject:[NSNumber numberWithInt:newPosition] afterDelay:0.0];
				}
				else
				{
					[self moveToNewPosition:newPosition
							  animationType:NO_ANIMATION];
				}
			}
			break;		// DONE -- found it
		}
		count++;
	}
}

- (KTDesign *)selectedDesign { return myDesign; }

- (void)setSelectedDesign:(KTDesign *)design
{
	[design retain];
	[myDesign release];
	myDesign = design;
	
	[self setCurrentSelectionToIdentifier:[design identifier]];
	[self setNeedsDisplay:YES];
}

#pragma mark -
#pragma mark Other

- (void) fastAnimateToNewPosition:(NSNumber *)aNewPosition
{
	[self moveToNewPosition:[aNewPosition intValue]
			  animationType:FAST_ANIMATION];
}


- (void)calculateWhatsVisible
{
	int availableWidth = [self bounds].size.width;
	
	myNumberOfDesignsVisible = myNumberOfDesignsCompletelyVisible = availableWidth / kOverlayWidth;
	
	int remainingWidth = availableWidth - (myNumberOfDesignsVisible * kOverlayWidth);
	
	if (remainingWidth > kMinimumPartialWidth)	// only deal with a partial last one if it will show a little
	{
		myPartialLastWidth = remainingWidth;
		myNumberOfDesignsVisible += 1;
	}
	else
	{
		myPartialLastWidth = 0;
	}
	
	// Resizing will affect whether "next" button is visible.  (Since it doesn't affect offset
	// from left, it doesn't affect "prev" button.)
	[oNextButton setTransparent:!(myListOffset + myNumberOfDesignsCompletelyVisible < [self totalDesignCount])];
	[oNextButton highlight:NO];
	[oNextButton setEnabled:YES];		// enable regardless in case it was disabled

}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
		int i;
		for (i = 0 ; i < kMaximumReasonableNumberOfVisibleThumbs; i++)
		{
			myTrackingRectTags[i] = -99;	// uninitialized value
		}
		myHoveredScreenIndex = -99;		// initially nothing hovered over
		mySelectedIndex = -99;
		myClickingScreenIndex = -99;
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(windowDidBecomeMain:)
													 name:NSWindowDidBecomeMainNotification
												   object:[self window]];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(windowDidResignMain:)
													 name:NSWindowDidResignMainNotification
												   object:[self window]];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(sheetDidEnd:)
													 name:NSWindowDidEndSheetNotification
												   object:[self window]];
	}
    return self;
}

/*!	Clear all tracking rects.  We do this if the height has changed
*/
- (void)clearTrackingRects
{
	int i;
	for (i = 0 ; i < kMaximumReasonableNumberOfVisibleThumbs; i++ )
	{
		if (myTrackingRectTags[i] > 0)	// remove?
		{
//		LOG((@"CLEARING rect index %d, tag %d", i, myTrackingRectTags[i] ));
			[self removeTrackingRect:myTrackingRectTags[i]];
			myTrackingRectTags[i] = -1;
		}
	}
}

/*!	Add or remove tracking rects as needed.
	Note we don't worry about the partial one on the right -- we have another view blocking things.
*/
- (void)updateTrackingRects
{
	// Get the location -- but note that this doesn't work if it's not relative to *this* window
	NSPoint windowMouseLoc = [[[self window] currentEvent] locationInWindow];
	NSPoint viewMouseLoc = [self convertPoint:windowMouseLoc fromView:nil];
	
	// Manage tracking rectangles
	int i;
	int numberActuallyShowing = MIN(myNumberOfDesignsVisible, [self totalDesignCount] - myListOffset);
	int theMax = MAX(myNumberOfDesignsVisible, [self totalDesignCount] - myListOffset);
	int maxTrackingRects = MIN(theMax, kMaximumReasonableNumberOfVisibleThumbs);
		
	for (i = 0 ; i < maxTrackingRects; i++ )
	{
		BOOL showHaveTrackingRect = (i < numberActuallyShowing);
		if (showHaveTrackingRect && myTrackingRectTags[i]<0)	// add?
		{
			NSRect trackingRect = NSMakeRect(kLeftMargin + kXThumbPosition + i*kOverlayWidth, 0, kThumbnailWidth, kThumbnailHeight+kYThumbPosition+kBottomMargin);
				// track the thumbnail, plus the space below it, so we can mouse over the text below

			NSTrackingRectTag tag = 
				[self addTrackingRect:trackingRect
								owner:self
							 userData:(void *)i
						 assumeInside:NO];
//		LOG((@"add tracking rect %@ at index %d .. tag = %d userData = %d", NSStringFromRect(trackingRect), i, tag, i));
		
			myTrackingRectTags[i] = tag;
			
			// Check if our mouse is in one of these added guys -- if so, refresh
			if (NSPointInRect(viewMouseLoc, trackingRect))
			{
				myHoveredScreenIndex = i;
				[self setNeedsDisplay:YES];
			}
		}
		else if (!showHaveTrackingRect &&  myTrackingRectTags[i] > 0)	// remove?
		{
//		LOG((@"REMOVING rect index %d, tag %d", i, myTrackingRectTags[i] ));
			[self removeTrackingRect:myTrackingRectTags[i]];
			myTrackingRectTags[i] = -1;
		}
	}
}

- (void)awakeFromNib
{
	[self calculateWhatsVisible];
	
	[oPrevButton setFocusRingType: NSFocusRingTypeNone];	// don't draw focus ring for now ... looks bad!
	[oNextButton setFocusRingType: NSFocusRingTypeNone];

}

- (void)inUse:(BOOL)aFlag;
{
	if (aFlag)
	{
		[self updateTrackingRects];
	}
	else
	{
		[self clearTrackingRects];
	}
}

// advice from this; http://www.cocoadev.com/index.pl?AddTrackingRect
- (void)viewWillMoveToWindow:(NSWindow *)win
{
    if (!win && [self window])
	{
		[self clearTrackingRects];
	}
    [super viewWillMoveToWindow:win];
}


/*!	Override this so we know how many will fit across
*/
- (void)resizeWithOldSuperviewSize:(NSSize)oldBoundsSize
{
	[super resizeWithOldSuperviewSize:oldBoundsSize];
	[self calculateWhatsVisible];
	[self updateTrackingRects];
}

/*!	Called too frequently for my tastes, but it seems to be the only way to intercept a changed
	toolbar visibity/hight, so we we blow away the TRACKING rects and recalculate.
*/

- (void)resetCursorRects
{
	[self clearTrackingRects];
	[self updateTrackingRects];
}

- (void)updateSelectedDesignWithWindowMousePosition:(NSPoint )mousePoint;
{
	KTDocument *document = [[NSDocumentController sharedDocumentController] currentDocument];
	if ([document isKindOfClass:[KTDocument class]])
	{
		KTDesign *design = [[self designsToShow] objectAtIndex:mySelectedIndex];
		[design loadLocalFontsIfNeeded];		// get a head start on loading local fonts.
		
		// Send the updated design to our controller. Bindings will take care of the rest
		NSDictionary *bindingsInfo = [self infoForBinding:@"selectedDesign"];
		id controller = [bindingsInfo objectForKey:NSObservedObjectKey];
		NSString *keyPath = [bindingsInfo objectForKey:NSObservedKeyPathKey];
		[controller setValue:design forKeyPath:keyPath];
		
		
		// Notify observers
		[[NSNotificationCenter defaultCenter]
	postNotificationName:kKTDesignChangedNotification
				  object:document
				userInfo:
					[NSDictionary dictionaryWithObjectsAndKeys:
						[NSNumber numberWithBool:YES], @"animate",
						NSStringFromPoint(mousePoint), @"mouse",
						nil]
			];
		
		[self resetCursorRects];
	}
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
	return YES;
}

- (void)mouseDown:(NSEvent *)theEvent;
{
	if (myHoveredScreenIndex < 0)	// ignore a mousedown if we're not inside a thumbnail
	{
		return;
	}
	int originalHoveredIndex = myHoveredScreenIndex;
	BOOL keepOn = YES;
	BOOL isInside = YES;
	NSPoint mouseLoc;
	NSRect trackingRect = NSMakeRect(kLeftMargin + kXThumbPosition + myHoveredScreenIndex*kOverlayWidth, 0, kThumbnailWidth, kThumbnailHeight+kYThumbPosition+kBottomMargin);
	NSRect textRect = NSMakeRect(kLeftMargin + kXThumbPosition + myHoveredScreenIndex*kOverlayWidth, 0, kThumbnailWidth, kYThumbPosition+kBottomMargin);

	// Do initial display of clcked state
	myClickingScreenIndex = myHoveredScreenIndex;
	[self display];
	int trackedHoverItem = originalHoveredIndex;
		
	while (keepOn)
	{
		theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSMouseEnteredMask | NSMouseExitedMask];
		mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
		isInside = [self mouse:mouseLoc inRect:trackingRect];
		
		switch ([theEvent type]) {
			
			// enter/exit: just keep track of where the mouse is
			case NSMouseExited:
				// swallow event.  Since this comes after the mouseentered once, we ignore it.
				break;
			case NSMouseEntered:
				trackedHoverItem = (int)[theEvent userData];
				break;
			case NSLeftMouseDragged:
				myClickingScreenIndex = isInside ? myHoveredScreenIndex : -1;
				myHoveredScreenIndex = isInside ? originalHoveredIndex : -1;
				[self display];
				break;
			case NSLeftMouseUp:
				myClickingScreenIndex = -1;	// no longer in mid-click
				myHoveredScreenIndex = trackedHoverItem;	// start hovering over whatever we are over
				if (isInside)
				{
					// Did mouseup happen in the text area, and there's a URL?
					int mouseUpIndex = myHoveredScreenIndex + myListOffset;
					if (mouseUpIndex >= [[self designsToShow] count])
					{
						mouseUpIndex = [[self designsToShow] count] - 1;	// BUGSID:35518
					}
					KTDesign *design = [[self designsToShow] objectAtIndex:mouseUpIndex];
					NSURL *url = [design URL];
					if (nil != url && [self mouse:mouseLoc inRect:textRect])	// did we click on the title
					{
						[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:url];
					}
					else	// regular click; select this.
					{
						int newIndex = myHoveredScreenIndex + myListOffset;
						if (newIndex != mySelectedIndex)
						{
							mySelectedIndex = newIndex;
							[self updateSelectedDesignWithWindowMousePosition:[theEvent locationInWindow]];
						}
					}
				}
				
				keepOn = NO;
				break;
			default:
				break;
		}
	}
	return;
}


- (void)mouseEntered:(NSEvent *)theEvent
{
//	LOG((@"%@", NSStringFromSelector(_cmd)));
	
	int indexOfItem = (int)[theEvent userData];
	// For now, let's just invalidate the whole thing to cause a redraw.  Maybe later we can optimize.
	myHoveredScreenIndex = indexOfItem;
	[self setNeedsDisplay:YES];
}


- (void)mouseExited:(NSEvent *)theEvent
{
//	LOG((@"%@ set myHoveredScreenIndex = -1", NSStringFromSelector(_cmd)));
	myHoveredScreenIndex = -1;	
	// For now, let's just invalidate the whole thing to cause a redraw.  Maybe later we can optimize.
	[self setNeedsDisplay:YES];
}

- (void)moveToNewPosition:(int)aNewPosition animationType:(int)animationType
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if (NO_ANIMATION != animationType && [defaults boolForKey:@"DoAnimations"])
	{
		int savedListOffset = myListOffset;
		int savedNumberOfDesignsVisible = myNumberOfDesignsVisible;
		int savedPartialLastWidth = myPartialLastWidth;
		
		@try
		{
			[oPrevButton setEnabled:NO];
			[oNextButton setEnabled:NO];	// disable both buttons for now, during animation

			// CREATE A BASE IMAGE FOR THE ANIMATION
			
			// Temporarily allow additional designs visible based on diff between old and new position
			int deltaItems = ABS(aNewPosition - myListOffset);
			myNumberOfDesignsVisible += deltaItems;
			myHoveredScreenIndex = -88;	// don't show any hover indication in the animation (I think)
			myPartialLastWidth = 0;
			if (aNewPosition < myListOffset)
			{
				myListOffset = aNewPosition;	// set new position for creation of animation item
			}

			int deltaX = deltaItems * kOverlayWidth;
			
			NSRect r = [self bounds];
			r.size.width += deltaX;

			myAnimationBaseImage = [[NSImage alloc] initWithSize:r.size];
			
			[myAnimationBaseImage lockFocus];
			[self drawRect:r];
			[myAnimationBaseImage unlockFocus];

			myListOffset = savedListOffset;
			myNumberOfDesignsVisible = savedNumberOfDesignsVisible;
			myPartialLastWidth = savedPartialLastWidth;

		
			// SET UP THE ANIMATION
			
			NSTimeInterval durationPerItem = 
				(FAST_ANIMATION == animationType)
					? TRANSITION_FAST_DURATION_PER
					: (([[NSApp currentEvent] modifierFlags] & NSShiftKeyMask)
						? TRANSITION_SLOWMO_DURATION_PER 
						: TRANSITION_DURATION_PER);

			NSTimeInterval duration = deltaItems * durationPerItem;

			// Use core image if we have it available; flip based on option key.

			myCoreImageAnimation = [KTAppDelegate coreImageAccelerated];
			
			myCoreImageAnimation ^= (0 != ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask));
			myLastAnimationPosition = 0;
			
			myUpcomingListOffset = aNewPosition;
			myAnimation = [[DesignPickerAnimation alloc] initWithDuration:duration animationCurve:NSAnimationEaseInOut];
			[myAnimation setDelegate:self];
			
			if (myCoreImageAnimation)
			{
				myAnimationCIImage = [[CIImage alloc] initWithBitmapImageRep:[myAnimationBaseImage bitmap]];
			}		
			
			[myAnimation setFrameRate:30.0];
			// Run the animation synchronously.
			[myAnimation startAnimation];
		}
		@finally
		{
			// Clean up after the animation has finished.
			[myAnimation release];				myAnimation = nil;
			[myAnimationBaseImage release];		myAnimationBaseImage = nil;
			[myAnimationCIImage release];		myAnimationCIImage = nil;
			
		}
	}
	myListOffset = aNewPosition;

	[self setNeedsDisplay:YES];
	[oPrevButton setEnabled:YES];
	[oNextButton setEnabled:YES];
	[oPrevButton highlight:NO];
	[oNextButton highlight:NO];
	
	// Set transparent, not hidden, because multiple clicks queued up on a button that gets  hidden results in an exception
	[oPrevButton setTransparent:!(myListOffset > 0)];	// enable if we can scroll back, even one
	[oNextButton setTransparent:!(myListOffset + myNumberOfDesignsCompletelyVisible < [self totalDesignCount])];
	[self updateTrackingRects];
}

// Option-click takes you to the end

- (IBAction) nextPage:(id)sender
{
	int totalCount = [self totalDesignCount];
	if (myListOffset + myNumberOfDesignsCompletelyVisible < totalCount)
	{
		int newPosition = myListOffset + myNumberOfDesignsCompletelyVisible;

		// adjust so that we fill up the view as much as possible
		if (newPosition > totalCount - myNumberOfDesignsCompletelyVisible
			|| ([[NSApp currentEvent] modifierFlags] & NSCommandKeyMask))
		{
			newPosition = totalCount - myNumberOfDesignsCompletelyVisible;
		}
		
		[self moveToNewPosition:newPosition animationType:ANIMATION];
// TODO: I may want to adjust this so it just puts the last one at the end
	}
}

// Option-click takes you to the beginning

- (IBAction) prevPage:(id)sender
{
	if (myListOffset)
	{
		int newPosition = MAX(0,myListOffset - myNumberOfDesignsCompletelyVisible);
		if ([[NSApp currentEvent] modifierFlags] & NSCommandKeyMask)
		{
			newPosition = 0;
		}
		[self moveToNewPosition:newPosition animationType:ANIMATION];
	}
}

// addTrackingRect:owner:userData:assumeInside: 

- (void)drawRect:(NSRect)rect
{
	NSRect overlayRect = NSMakeRect(0,0,kOverlayWidth, kOverlayHeight);

	if (nil != myAnimation)
	{
		float currentValue = [myAnimation currentValue];
		float currentDelayedValue = currentValue;
		if (myCoreImageAnimation)		// cartoony delay to actually start moving while leaning into move
		{
#define THRESH (0.05)
#define REMAINDER (1.0 - THRESH)
#define RECIP (1.0 / REMAINDER)
			currentDelayedValue = (currentValue < THRESH)
				? 0.0
				: (RECIP * (currentValue - THRESH));
		}
		
		// offset always progresses from starting to ending values
		float fractionalOffset = ((myUpcomingListOffset - myListOffset) * currentDelayedValue);
		float fractionalXOffset = fractionalOffset * kOverlayWidth;
		NSRect sourceRect = [self bounds];
		if (myUpcomingListOffset > myListOffset)	// moving "right", starting offset at 0 and incrementing
		{
			sourceRect.origin.x = fractionalXOffset;
		}
		else	// moving "left"
		{
			sourceRect.origin.x = ((myListOffset - myUpcomingListOffset) * kOverlayWidth) + fractionalXOffset;
		}

		// Only use core image if we have hardware accelleration
		if (myCoreImageAnimation)
		{
			float animationDelta = currentValue - myLastAnimationPosition;
			myLastAnimationPosition = currentValue;
			
			CIImage *im = myAnimationCIImage;
			CGRect ext = [im extent];
			CIFilter *f =[CIFilter filterWithName:@"CIAffineTransform"];
			[f setValue:im forKey:@"inputImage"];
			NSAffineTransform *transform = [NSAffineTransform transform];
// TODO: redo this logic now that duration is per object
			float xShear = animationDelta * 5.0;
			if ([myAnimation duration] >= 5 * TRANSITION_SLOWMO_DURATION_PER)	// give 'em a little bit more show if slow mo
			{
				xShear *= TRANSITION_SLOWMO_DURATION_PER / TRANSITION_DURATION_PER;
			}
			xShear = MIN(0.15, xShear);
			if (myUpcomingListOffset > myListOffset)
			{
				xShear *= -1;
			}
			
			[transform shearXBy:xShear];
			[f setValue:transform forKey:@"inputTransform"];
			im = [f valueForKey:@"outputImage"];
			
			f = [CIFilter filterWithName:@"CIMotionBlur"];
			[f setValue:im forKey:@"inputImage"];
			float radius = animationDelta * 50.0;
			
			radius = MIN(10.0, radius);
			
			[f setValue:[NSNumber numberWithFloat:radius] forKey:@"inputRadius"];
			im = [f valueForKey:@"outputImage"];
			
			CIVector *cropRect =[CIVector vectorWithX:0 Y:0 Z: ext.size.width W: ext.size.height];
			f = [CIFilter filterWithName:@"CICrop"];
			[f setValue:im forKey:@"inputImage"];
			[f setValue:cropRect forKey:@"inputRectangle"];
			im = [f valueForKey:@"outputImage"];
			
//#ifdef DEBUG
//			NSString *filePath = [NSString stringWithFormat:@"/tmp/frame_%.4f.png", currentValue];
//			NSData *data = [[im bitmap] TIFFRepresentation];
//			[data writeToFile:filePath atomically:YES];
//#endif
			[im drawInRect:[self bounds] fromRect:sourceRect operation:NSCompositeSourceOver fraction:1.0];
		}
		else	// just draw the image directly
		{
			[myAnimationBaseImage drawInRect:[self bounds] fromRect:sourceRect operation:NSCompositeSourceOver fraction:1.0];
		}
		
		// Show design covers on the left and right side to cover up edges
		[sDesignCoverLeft drawAtPoint:NSMakePoint(-kOverlayWidth+9, 0)
						 fromRect:overlayRect
						operation:NSCompositeSourceOver fraction:1.0];

		[sDesignCoverRight drawAtPoint:NSMakePoint([self bounds].size.width - kCoverXPosition, 0)
							  fromRect:overlayRect
							 operation:NSCompositeSourceOver fraction:1.0];
	}
	else
	{
		int maxIndex = myListOffset + myNumberOfDesignsVisible;
			
		if (maxIndex > [self totalDesignCount])
		{
			maxIndex = [self totalDesignCount];
		}
				
		int designIndex, displayIndex;
		for (designIndex = myListOffset, displayIndex = 0 ; designIndex < maxIndex; designIndex++, displayIndex++ )
		{
			// We draw a few pixels up from zero point to make extra room for the titles.
			NSPoint overlayPoint = NSMakePoint(kLeftMargin + displayIndex*kOverlayWidth,kBottomMargin);
			NSPoint noMarginOverlayPoint = NSMakePoint(kLeftMargin + displayIndex*kOverlayWidth,0);
			
			KTDesign *design = [[self designsToShow] objectAtIndex:designIndex];
			NSImage *thumbnail = [design thumbnail];
			if (nil == thumbnail)
			{
				thumbnail = sUnknownThumbnail;
			}
			float width = [thumbnail size].width;
			float height = [thumbnail size].height;
			[thumbnail drawAtPoint:NSMakePoint((kThumbnailWidth - width)/2.0   +    kLeftMargin + kXThumbPosition + displayIndex*kOverlayWidth,
											   (kThumbnailHeight - height)/2.0 +    kBottomMargin + kYThumbPosition)
									 fromRect:NSMakeRect(0,0,width, height)
									operation:NSCompositeSourceOver fraction:1.0];
			
			if (displayIndex == mySelectedIndex - myListOffset)	// Is this one selected?
			{
// NOTE: This graphic is designed NOT to be shown with a bottom margin.
// So we draw it at the bottom of the view, with NO margin.
// Ideally, all the graphics would be set up for that....
				[sDesignSelectedFrame drawAtPoint:noMarginOverlayPoint
										 fromRect:overlayRect
										operation:NSCompositeSourceOver fraction:1.0];
				
				if (displayIndex == myClickingScreenIndex)	// Is this one BEING clicked on?
				{			
					[sDesignSelectedClickGloss drawAtPoint:overlayPoint
										  fromRect:overlayRect
										 operation:NSCompositeSourceOver fraction:1.0];
				}
				else
				{
					[sDesignSelectedGloss drawAtPoint:overlayPoint
											 fromRect:overlayRect
											operation:NSCompositeSourceOver fraction:1.0];
				}
			}
			else
			{
				[sDesignNormalFrame drawAtPoint:overlayPoint
									   fromRect:overlayRect
									  operation:NSCompositeSourceOver fraction:1.0];

				if (displayIndex == myClickingScreenIndex)	// Is this one BEING clicked on?
				{			
					[sDesignClickGloss drawAtPoint:overlayPoint
										  fromRect:overlayRect
										 operation:NSCompositeSourceOver fraction:1.0];
				}
				else
				{
					[sDesignNormalGloss drawAtPoint:overlayPoint
									   fromRect:overlayRect
									  operation:NSCompositeSourceOver fraction:1.0];
				}
			}
			if (displayIndex == myHoveredScreenIndex && [[self window] isMainWindow] && nil == [[self window] attachedSheet])
			{			
				[sDesignHover drawAtPoint:overlayPoint
									   fromRect:overlayRect
									  operation:NSCompositeSourceOver fraction:1.0];
				
				float centerX = overlayPoint.x + (kOverlayWidth/2.0);
				NSMutableAttributedString *text
					= [[[NSMutableAttributedString alloc] initWithString:[design title] attributes:sAttributes] autorelease];
				NSString *contributor = [design contributor];
				if (nil != contributor && ![contributor isEqualToString:@""])
				{
					NSURL *url = [design URL];
					if (nil != url)
					{
						// URL -- append contributor name with a hyperlink looking underline
						[text appendAttributedString:
							[[[NSAttributedString alloc] initWithString:
										[NSString stringWithFormat:@" %C ", 0x2014 /* em dash */]
														attributes:sContributorAttributes] autorelease]];
						[text appendAttributedString:
							[[[NSAttributedString alloc] initWithString:contributor
															attributes:sContributorLinkAttributes] autorelease]];
					}
					else
					{
						// no URL -- just append contributor
						[text appendAttributedString:
							[[[NSAttributedString alloc] initWithString:
								[NSString stringWithFormat:@" %C %@", 0x2014 /* em dash */, contributor]
															 attributes:sContributorAttributes] autorelease]];
					}
				}

				// draw name only if we are key window
				if ([[self window] isMainWindow])
				{
					float textWidth = [text size].width;
					float leftPoint = centerX - (textWidth/2.0);
					
					if (leftPoint < kTextMargin)
					{
						leftPoint = kTextMargin;
					}
					else if (leftPoint + textWidth > [self bounds].size.width - kTextMargin)
					{
						leftPoint = [self bounds].size.width - kTextMargin - textWidth;
					}
					
					// TODO: What if title won't fit???
					
					[text drawAtPoint:NSMakePoint(leftPoint,kBottomMargin+kYTextPosition)]; 
				}
			}
		}
		if (myPartialLastWidth)
		{
			// Draw the mask over the right edge to cover up partially visible last one
			[sDesignCoverRight drawAtPoint:NSMakePoint([self bounds].size.width - kCoverXPosition, 0)
								  fromRect:overlayRect
								 operation:NSCompositeSourceOver fraction:1.0];
		}
	}
}

/*!	Refresh display when becoming main or losing main, so we remove/show any highlight
*/

- (void)windowDidBecomeMain:(NSNotification *)notification;
{
	[self setNeedsDisplay:YES];
}

- (void)windowDidResignMain:(NSNotification *)notification;
{
	[self setNeedsDisplay:YES];
}

- (void)sheetDidEnd:(NSNotification *)notification;
{
	[self setNeedsDisplay:YES];
}


@end
