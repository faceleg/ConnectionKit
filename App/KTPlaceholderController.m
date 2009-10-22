//
//  KTPlaceholderController.m
//  Marvel
//
//  Created by Dan Wood on 10/16/06.
//  Copyright 2006-2009 Karelia Software. All rights reserved.
//

#import "KTPlaceholderController.h"

#import "NSColor+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSThread+Karelia.h"
#import <QTKit/QTKit.h>
#import "KSLicensedAppDelegate.h"
#import "KSNetworkNotifier.h"
#import "KSYellowStickyWindow.h"
#import "Registration.h"

enum { LICENSED = 0, UNDISCLOSED, DISCLOSED, NO_NETWORK };




@implementation KTPlaceholderController

@synthesize sticky = _sticky;

- (id)init
{
    self = [super initWithWindowNibName:@"Placeholder"];
    return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}



- (void) updateLicenseStatus:(NSNotification *)aNotification
{
	int windowState = LICENSED;
	if (nil == gRegistrationString )
	{
		// show disclosure triangle and such.
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		windowState = [defaults boolForKey:@"hiddenIntro"] ? UNDISCLOSED : ([KSNetworkNotifier isNetworkAvailable] ? DISCLOSED : NO_NETWORK);
	}
}

- (IBAction)showWindow:(id)sender;
{

	[super showWindow:sender];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

	[oRecentDocsController addObjects:[[NSDocumentController sharedDocumentController] recentDocumentURLs]];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(updateLicenseStatus:)
												 name:kKSLicenseStatusChangeNotification
											   object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLicenseStatus:) name:kKSNetworkIsAvailableNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLicenseStatus:) name:kKSNetworkIsNotAvailableNotification object:nil];
		
	NSMutableAttributedString *attrString = [[[oHighLink attributedTitle] mutableCopyWithZone:[oHighLink zone]] autorelease];
	NSRange range = NSMakeRange(0,[attrString length]);
	
	[attrString addAttribute:NSForegroundColorAttributeName value:[NSColor linkColor] range:range];
	[attrString addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:1]  range:range];
	[attrString addAttribute:NSCursorAttributeName value:[NSCursor pointingHandCursor] range:range];
	[oHighLink setAttributedTitle:attrString];
	
	attrString = [[[oLowLink attributedTitle] mutableCopyWithZone:[oLowLink zone]] autorelease];
	range = NSMakeRange(0,[attrString length]);
	
	[attrString addAttribute:NSForegroundColorAttributeName value:[NSColor linkColor] range:range];
	[attrString addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:1]  range:range];
	[attrString addAttribute:NSCursorAttributeName value:[NSCursor pointingHandCursor] range:range];
	[oLowLink setAttributedTitle:attrString];
	
	// NSLocalizedString(@"You are running a demonstration version of Sandvox.", "indicator that this is a demo")];
	[oDemoNotification setStringValue:NSLocalizedString(@"Please purchase a license to Sandvox.", "indicator that this is a demo")];

	[self updateLicenseStatus:nil];

	[[self window] center];
	[[self window] setLevel:NSNormalWindowLevel];
	[[self window] setExcludedFromWindowsMenu:YES];
	
}

// Attach sticky here becuase it seems we can only really make this child window appear when the window
// is already appearing, and I don't see a notification for window-did-show.  We don't want to orderFront
// the sticky window because that's weird if our welcome window is not in front.
- (void)windowDidBecomeKey:(NSNotification *)notification
{
	if (!self.sticky)
	{
		_sticky = [[KSYellowStickyWindow alloc]
				   initWithContentRect:NSMakeRect(0,0,kStickyViewWidth,kStickyViewHeight)
				   styleMask:NSBorderlessWindowMask
				   backing:NSBackingStoreBuffered
				   defer:YES];
		
		[oStickyRotatedView setFrameCenterRotation:8.0];
		
		NSColor *blueColor = [NSColor colorWithCalibratedRed:0.000 green:0.295 blue:0.528 alpha:1.000];
		
		NSDictionary *attr1 = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont fontWithName:@"Marker Felt" size:20.0], NSFontAttributeName, nil];
		NSDictionary *attr2 = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont fontWithName:@"Chalkboard" size:12.0], NSFontAttributeName, nil];
		
		NSMutableAttributedString *attrStickyText = [[[NSMutableAttributedString alloc] initWithString:
													  NSLocalizedString(@"This is a demo of Sandvox", @"title of reminder note - please make sure this will fit on welcome window when unlicensed") attributes:attr1] autorelease];	
		[attrStickyText appendAttributedString:[[[NSAttributedString alloc] initWithString:@"\n" attributes:attr1] autorelease]];
		[attrStickyText appendAttributedString:[[[NSAttributedString alloc] initWithString:NSLocalizedString(@"Sandvox is fully functional except that only the home page can be published.", @"explanation of demo - please make sure this will fit on welcome window when unlicensed") attributes:attr2] autorelease]];
		[attrStickyText addAttribute:NSForegroundColorAttributeName value:blueColor range:NSMakeRange(0, [attrStickyText length])];
		[attrStickyText setAlignment:NSCenterTextAlignment range:NSMakeRange(0, [attrStickyText length])];
		
		[[oStickyTextView textStorage] setAttributedString:attrStickyText];
		[_sticky setContentView:oStickyView];
		[_sticky setAlphaValue:0.0];
		NSPoint convertedWindowOrigin = [[self window] convertBaseToScreen:NSMakePoint(750,300)];
		[_sticky setFrameTopLeftPoint:convertedWindowOrigin];
		
		[[self window] addChildWindow:_sticky ordered:NSWindowAbove];
		
		 // Set up the animation for this window so we will get delegate methods
		 [_sticky.animator setAlphaValue:1.0];	// animate open
	}		
}

- (IBAction) doNew:(id)sender
{
	[[self window] orderOut:self];
	[[NSDocumentController sharedDocumentController] newDocument:nil];
}

- (IBAction) doOpen:(id)sender
{
	[[self window] orderOut:self];
	[[NSDocumentController sharedDocumentController] openDocument:self];
}

- (IBAction) openLicensing:(id)sender
{
	[[NSApp delegate] performSelector:@selector(showRegistrationWindow:) withObject:sender afterDelay:0.0];
}

- (IBAction) openScreencastLargeSize:(id)sender;
{
	[[NSApp delegate] openScreencastLargeSize:nil];
}

- (IBAction) openHigh:(id)sender;		// LEGACY -- BACKWARD COMPATIBLE IF NIBS ARE NOT LOCALIZED YET
{
	[[NSApp delegate] openScreencastLargeSize:nil];
}

- (IBAction) openScreencastSmallSize:(id)sender;
{
	[[NSApp delegate] openScreencastSmallSize:nil];
}

- (IBAction) openLow:(id)sender;	// LEGACY -- BACKWARD COMPATIBLE IF NIBS ARE NOT LOCALIZED YET
{
	[[NSApp delegate] openScreencastSmallSize:nil];
}


@end
