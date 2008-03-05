//
//  KTQuickStartController.m
//  Marvel
//
//  Created by Terrence Talbot on 1/6/06.
//  Copyright 2006 Biophony LLC. All rights reserved.
//

#import "KTQuickStartController.h"

#import "NSColor+Karelia.h"
#import "NSThread+Karelia.h"
#import "Registration.h"

@implementation KTQuickStartController

- (id)init
{
	NSString *nibName = @"Introduction";
	if (self = [super initWithWindowNibName:nibName])
	{
		;
	}
	return self;
}

// Start it up

- (void) doWelcomeAlert:(id)bogus
{
	//(void) [NSApp runModalForWindow:[self window]];
	[[self window] center];
	[[self window] makeKeyAndOrderFront:self];
}


- (IBAction) openLicensing:(id)sender
{
	[NSApp stopModal];
	[[NSApp delegate] performSelector:@selector(showRegistrationWindow:) withObject:nil afterDelay:0.0];
}

- (IBAction) done:(id)sender
{
	[NSApp stopModal];	
}

- (void)incrementOpacity:(NSTimer*)theTimer
{
	myOpacity += 0.05;
	[[self window] setAlphaValue:myOpacity];
	if (myOpacity >= 1.0)
	{
		[theTimer invalidate];
		[theTimer release];
		(void) [NSApp runModalForWindow:[self window]];
		[[self window] close];
	}
}

- (void)windowDidLoad
{
	myOpacity = 0.0;
	[[self window] setAlphaValue:myOpacity];		// set to transparent before we see it!
	
	(void) [[NSTimer scheduledTimerWithTimeInterval:(1.0/30.0) target:self selector:@selector(incrementOpacity:) userInfo:nil repeats:YES] retain];
	//[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSModalPanelRunLoopMode];
	
	NSString *path = nil;
	
	path = [[NSBundle mainBundle] pathForResource:@"preview" ofType:@"mp4"];

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
	
	NSMutableAttributedString *attrString = [[[oHighLink attributedTitle] mutableCopyWithZone:[oHighLink zone]] autorelease];
	NSRange range = NSMakeRange(0,[attrString length]);
	
	[attrString addAttribute:NSForegroundColorAttributeName value:
		[NSColor linkColor]
					   range:range];
	[attrString addAttribute:NSUnderlineStyleAttributeName value:
		[NSNumber numberWithInt:1]
					   range:range];
	[oHighLink setAttributedTitle:attrString];
	
	attrString = [[[oLowLink attributedTitle] mutableCopyWithZone:[oLowLink zone]] autorelease];
	range = NSMakeRange(0,[attrString length]);
	
	[attrString addAttribute:NSForegroundColorAttributeName value:
		[NSColor linkColor]
					   range:range];
	[attrString addAttribute:NSUnderlineStyleAttributeName value:
		[NSNumber numberWithInt:1]
					   range:range];
	[oLowLink setAttributedTitle:attrString];
	
}

- (void)windowWillClose:(NSNotification *)notification;
{
	[NSApp stopModal];
	[oPreviewMovie setMovie:nil];	// make the movie go away
	
	// Upon closing this window, perhaps open up the new/open dialog.  Not typical but this helps
	[[NSApp delegate] performSelector:@selector(applicationOpenUntitledFile:) withObject:NSApp afterDelay:0.0];
}

- (IBAction) openHigh:(id)sender;
{
	[[NSApp delegate] openHigh:nil];
	//[[NSApp delegate] performSelector:@selector(openHigh:) withObject:nil afterDelay:0.0];
}

- (IBAction) openLow:(id)sender;
{
	[[NSApp delegate] openLow:nil];
	//[[NSApp delegate] performSelector:@selector(openLow:) withObject:nil afterDelay:0.0];
}

- (IBAction) openIntro:(id)sender
{
	[NSApp showHelp:nil];
	//[NSApp performSelector:@selector(showHelp:) withObject:nil afterDelay:0.0];
}




@end
