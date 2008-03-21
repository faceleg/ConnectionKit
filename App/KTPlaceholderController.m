//
//  KTPlaceholderController.m
//  Marvel
//
//  Created by Dan Wood on 10/16/06.
//  Copyright 2006 Karelia Software. All rights reserved.
//

#import "KTPlaceholderController.h"
#import "NSThread+Karelia.h"
#import "NSColor+Karelia.h"
#import <QTKit/QTKit.h>
#import "Registration.h"
#import "KSAppDelegate.h"

enum { LICENSED = 0, UNDISCLOSED, DISCLOSED };

@implementation KTPlaceholderController

- (id)init
{
    self = [super initWithWindowNibName:@"Placeholder"];
    return self;
}


- (void)adjustWindow:(int)windowState animate:(BOOL)anAnimate
{
	int newBottom = 0;
	switch (windowState)
	{
		case LICENSED:		newBottom = NSMaxY([oHideWhenLicensed frame]);		break;
		case UNDISCLOSED:	newBottom = NSMaxY([oDisclosureTop frame]);			break;
		case DISCLOSED:		newBottom = NSMinY([oDisclosureBottom frame]) - 20;	break;
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
		NSAssert([NSThread isMainThread], @"should not be creating intro movie from a background thread");
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
		windowState = [defaults boolForKey:@"hiddenIntro"] ? UNDISCLOSED : DISCLOSED;
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
	[self updateLicenseStatus:nil];
		
	NSMutableAttributedString *attrString = [[[oHighLink attributedTitle] mutableCopyWithZone:[oHighLink zone]] autorelease];
	NSRange range = NSMakeRange(0,[attrString length]);
	
	[attrString addAttribute:NSForegroundColorAttributeName value:[NSColor linkColor] range:range];
	[attrString addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:1]  range:range];
	[oHighLink setAttributedTitle:attrString];
	
	attrString = [[[oLowLink attributedTitle] mutableCopyWithZone:[oLowLink zone]] autorelease];
	range = NSMakeRange(0,[attrString length]);
	
	[attrString addAttribute:NSForegroundColorAttributeName value:[NSColor linkColor] range:range];
	[attrString addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:1]  range:range];
	[oLowLink setAttributedTitle:attrString];
	
	[[self window] center];
	[[self window] setLevel:NSNormalWindowLevel];
	[[self window] setExcludedFromWindowsMenu:YES];
}

- (IBAction) disclose:(id)sender;
{
	NSUserDefaultsController *controller = [NSUserDefaultsController sharedUserDefaultsController];
	NSUserDefaults *defaults = [controller defaults];
	BOOL shouldAnimate = [defaults boolForKey:@"DoAnimations"];
	
	[self adjustWindow:([sender state] ? DISCLOSED : UNDISCLOSED) animate:shouldAnimate];
}

- (IBAction) doNew:(id)sender
{
	[[self window] orderOut:self];
	[[NSDocumentController sharedDocumentController] newDocument:nil];

	[[NSApp delegate] performSelector:@selector(checkPlaceholderWindow:) 
						   withObject:nil
						   afterDelay:0.0];
}

- (IBAction) doOpen:(id)sender
{
	[[self window] orderOut:self];
	[[NSDocumentController sharedDocumentController] openDocument:self];

	[[NSApp delegate] performSelector:@selector(checkPlaceholderWindow:) 
			   withObject:nil
			   afterDelay:0.0];
	
}

- (IBAction) openLicensing:(id)sender
{
	[[NSApp delegate] performSelector:@selector(showRegistrationWindow:) withObject:nil afterDelay:0.0];
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
