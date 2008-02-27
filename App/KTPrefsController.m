//
//  KTPrefsController.m
//  Marvel
//
//  Copyright (c) 2005 Biophony LLC. All rights reserved.
//

// $Id$

#import "KTPrefsController.h"

#import "KT.h"
#import "KTApplication.h"
#import "KTAppDelegate.h"
#import "KSEmailAddressComboBox.h"
#import "CIImage+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSApplication+Karelia.h"


static KTPrefsController *sSharedPrefsController = nil;


@implementation KTPrefsController

#pragma mark Initialization Methods


+ (KTPrefsController *)sharedPrefsController;
{
    if ( nil == sSharedPrefsController ) 
	{
        sSharedPrefsController = [[self alloc] init];
	}

    return sSharedPrefsController;
}

- (id)init
{
	[KSEmailAddressComboBox setWillAddAnonymousEntry:NO];
	[KSEmailAddressComboBox setWillIncludeNames:NO];
	self = [super initWithWindowNibName:@"Prefs"];
    if (self)
	{
    }
    return self;
}


- (void)dealloc
{
	NSUserDefaultsController *controller = [NSUserDefaultsController sharedUserDefaultsController];

	[controller removeObserver:self forKeyPath:@"values.KTPreferredJPEGQuality"];
	[controller removeObserver:self forKeyPath:@"values.KTPrefersPNGFormat"];
	[controller removeObserver:self forKeyPath:@"values.LiveDataFeeds"];
//	[controller removeObserver:self forKeyPath:@"values.AutosaveDocuments"];

	[mySampleImage release];
	
	[super dealloc];
}

- (void)updateImageSettingsBlowAway:(BOOL)aBlowAway;
{
	
	// PNG FORMAT OR JPEG QUALITY ... BLOW AWAY IMAGE CACHE WHEN CHANGED.
	
	if (nil == mySampleImage)
	{
		// public domain US government image: http://invasivespecies.nbii.gov/gardening.html
		mySampleImage = [[NSImage imageNamed:@"quality_sample"] retain];
	}
	NSUserDefaultsController *controller = [NSUserDefaultsController sharedUserDefaultsController];
	NSUserDefaults *defaults = [controller defaults];
	if ([defaults boolForKey:@"KTPrefersPNGFormat"])
	{
		[oCompressionSample setHidden:YES];
	}
	else
	{
		[oCompressionSample setHidden:NO];
		float quality = [defaults floatForKey:@"KTPreferredJPEGQuality"];
		
		NSData *jpegData = [mySampleImage JPEGRepresentationWithQuality:quality];
		NSImage *newImage = [[[NSImage alloc] initWithData:jpegData] autorelease];
		[newImage normalizeSize];
		[oCompressionSample setImage:newImage];
	}
	
	// Blow away caches, but only if the keypath is real -- meaning the value actually changed.
	if (aBlowAway)
	{
		// Blow away the ENTIRE cache, of all documents ever opened.
		
		// Note that NSSearchPath.. and NSHomeDirectory return home directory path without resolving
		// symbolic links so they should match up.
		
		NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES);
		if ( [libraryPaths count] == 1 )
		{
			NSString *cachePath = [libraryPaths objectAtIndex:0];
			cachePath = [cachePath stringByAppendingPathComponent:[NSApplication applicationName]];
			cachePath = [cachePath stringByAppendingPathComponent:@"Sites"];
			cachePath = [cachePath stringByAppendingPathExtension:@"noindex"];
			
			// Double-check!
			if (![cachePath hasPrefix:NSHomeDirectory()]
				|| [cachePath isEqualToString:NSHomeDirectory()]
				|| [cachePath isEqualToString:@"/"]
				|| NSNotFound == [cachePath rangeOfString:@"Library/Caches"].location)
			{
				NSLog(@"Not removing image cache path from %@", cachePath);
			}
			else
			{
				NSFileManager *fm = [NSFileManager defaultManager];
				[fm removeFileAtPath:cachePath handler:nil];
				NSLog(@"Removed cache files from %@", cachePath);
			}
		}
	}	
}

// Scale down if it's bigger than 150% of what will show.  That will allow us to drag in approximately sized
// small images for an exact test.

- (IBAction) updateSampleImage:sender		
{
#define WIDTH 100
#define HEIGHT 75

	[mySampleImage release];
	
	NSImage *newImage = [sender image];
	NSBitmapImageRep *bitmap = [newImage bitmap];
	
	if ( [bitmap pixelsWide] > (1.5 * WIDTH) || [bitmap pixelsHigh] > (1.5 * WIDTH) )
	{
		CIImage *im = [newImage toCIImage];
		// Show the top/center of the image.  This crop & center it.
		im = [im scaleToWidth:WIDTH height:HEIGHT behavior:kCoverRect alignment:NSImageAlignCenter opaqueEdges:YES];
		
		newImage = [im toNSImageBitmap];
	}
	mySampleImage = [newImage retain];
	[self updateImageSettingsBlowAway:NO];
}

- (void)windowDidLoad
{
	NSUserDefaultsController *controller = [NSUserDefaultsController sharedUserDefaultsController];
	
	[controller addObserver:self forKeyPath:@"values.KTPreferredJPEGQuality" options:(NSKeyValueObservingOptionNew) context:nil];
	[controller addObserver:self forKeyPath:@"values.KTPrefersPNGFormat" options:(NSKeyValueObservingOptionNew) context:nil];
	[controller addObserver:self forKeyPath:@"values.LiveDataFeeds" options:(NSKeyValueObservingOptionNew) context:nil];
//	[controller addObserver:self forKeyPath:@"values.AutosaveDocuments" options:(NSKeyValueObservingOptionNew) context:nil];

	[oObjectController setContent:self];
	

	[oCompressionSample setEditable:YES];
	[oCompressionSample setImageFrameStyle:NSImageFrameGrayBezel];	// NSImageFrameGrayBezel
	[oCompressionSample setAction:@selector(updateSampleImage:)];
	[oCompressionSample setTarget:self];
	[oCompressionSample setImageScaling:NSScaleNone];	// if we scaled, it would be all wonky
	
	// Fix the transparent background
//	[oHaloscanTextView setDrawsBackground:NO];
//	NSScrollView *scrollView = [oHaloscanTextView enclosingScrollView];
//	[scrollView setDrawsBackground:NO];
//	[[scrollView contentView] setCopiesOnScroll:NO];

	[[self window] center];
	
	// Kick things off, initialize image stuff
	[self updateImageSettingsBlowAway:NO];
}

- (void)observeValueForKeyPath:(NSString *)aKeyPath
                      ofObject:(id)anObject
                        change:(NSDictionary *)aChange
                       context:(void *)aContext
{
//	NSLog(@"observeValueForKeyPath: %@", aKeyPath);
//	NSLog(@"                object: %@", anObject);
//	NSLog(@"                change: %@", [aChange description]);

	if ([aKeyPath isEqualToString:@"values.LiveDataFeeds"])
	{
		// FIXME: Need a replacement for this
//		[[NSNotificationCenter defaultCenter] postNotificationName:kKTWebViewMayNeedRefreshingNotification
//															object:nil];
	}
//	else if ([aKeyPath isEqualToString:@"values.AutosaveDocuments"])
//	{
//		[[NSApp delegate] toggleAutosave:nil];
//	}
	else
	{
		[self updateImageSettingsBlowAway:(nil != aKeyPath)];
	}
}

- (IBAction) windowHelp:(id)sender
{
	[NSApp showHelpPage:@"Preferences"];	// HELPSTRING
}



@end
