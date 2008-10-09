//
//  KTPlaceholderController.m
//  Marvel
//
//  Created by Dan Wood on 10/16/06.
//  Copyright 2006 Karelia Software. All rights reserved.
//

#import "KTPlaceholderController.h"

#import "NSColor+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSThread+Karelia.h"
#import <QTKit/QTKit.h>
#import "KSLicensedAppDelegate.h"
#import "KSNetworkNotifier.h"

#import "Registration.h"

enum { LICENSED = 0, UNDISCLOSED, DISCLOSED, NO_NETWORK };

@implementation KTPlaceholderController

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


- (void)adjustWindow:(int)windowState animate:(BOOL)anAnimate
{
	int newBottom = 0;
	switch (windowState)
	{
		case LICENSED:		newBottom = NSMaxY([oHideWhenLicensed frame]);		break;
		case UNDISCLOSED:	newBottom = NSMaxY([oDisclosureTop frame]);			break;
		case DISCLOSED:		newBottom = NSMinY([oDisclosureBottom frame]) - 20;	break;
		case NO_NETWORK:	newBottom = NSMaxY([oDisclosureBottom frame]);		break;
	}
	
	NSWindow *window = [self window];
	NSRect windowFrame = [window frame];
	NSRect contentFrame = [NSWindow contentRectForFrameRect:windowFrame styleMask:[window styleMask]];
	
	contentFrame.origin.y += newBottom;
	contentFrame.size.height -= newBottom;
	
	NSRect frameRect = [NSWindow frameRectForContentRect:contentFrame styleMask:[window styleMask]];
	[window setFrame:frameRect display:YES animate:anAnimate];
	
	if (DISCLOSED == windowState)
	{
		// fire up the quicktime preview
		NSString *path = [[NSBundle mainBundle] pathForResource:@"preview" ofType:@"mp4"];
		NSError *error = nil;
		OBASSERTSTRING([NSThread isMainThread], @"should not be creating intro movie from a background thread");
		QTMovie *movie = [QTMovie movieWithFile:path error:&error];
		if (nil == movie)
		{
			NSLog(@"couldn't read movie %@; %@", path, error);
		}
		else
		{
			NSDictionary *attr = [NSDictionary dictionaryWithObjectsAndKeys:
								  [NSNumber numberWithBool:YES], QTMovieLoopsAttribute, nil];
			[movie  setMovieAttributes:attr];
			[oPreviewMovie setMovie:movie];
			[oPreviewMovie play:nil];
		}
	}
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
	[self adjustWindow:windowState animate:(nil != aNotification)];	// animate if it's a real notification
}

- (IBAction)showWindow:(id)sender;
{

	[super showWindow:sender];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(updateLicenseStatus:)
												 name:kKSLicenseStatusChangeNotification
											   object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLicenseStatus:) name:kKSNetworkIsAvailableNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLicenseStatus:) name:kKSNetworkIsNotAvailableNotification object:nil];

	[self updateLicenseStatus:nil];
		
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
	
	// LATER -- FOR VARIATIONS.  Get the localized strings collected though.
//	[oDemoNotification setStringValue:NSLocalizedString(@"You are running a demonstration version of Sandvox.", "indicator that this is a demo")];
//	[oDemoNotification setStringValue:NSLocalizedString(@"Please purchase a license to Sandvox.", "indicator that this is a demo")];
	
	[[self window] center];
	[[self window] setLevel:NSNormalWindowLevel];
	[[self window] setExcludedFromWindowsMenu:YES];
}

- (IBAction) disclose:(id)sender;
{
	NSUserDefaultsController *controller = [NSUserDefaultsController sharedUserDefaultsController];
	NSUserDefaults *defaults = [controller defaults];
	BOOL shouldAnimate = [defaults boolForKey:@"DoAnimations"];
	
	[self adjustWindow:([sender state] ? ([KSNetworkNotifier isNetworkAvailable] ? DISCLOSED : NO_NETWORK) : UNDISCLOSED) animate:shouldAnimate];
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

- (IBAction) openHigh:(id)sender;
{
	[[NSApp delegate] openHigh:nil];
}

- (IBAction) openLow:(id)sender;
{
	[[NSApp delegate] openLow:nil];
}

@end
