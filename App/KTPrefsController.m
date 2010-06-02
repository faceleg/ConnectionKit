//
//  KTPrefsController.m
//  Marvel
//
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

// $Id$

#import "KTPrefsController.h"

#import "KT.h"
#import "KTApplication.h"
#import "KSEmailAddressComboBox.h"
#import "CIImage+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSImage+KTExtensions.h"
#import "NSApplication+Karelia.h"
#import "KSAbstractBugReporter.h"
#import <Sparkle/Sparkle.h>


@implementation KTPrefsController

#pragma mark Initialization Methods


- (id)init
{
	self = [super init];
    if (self)
	{
		
    }
    return self;
}


- (void)dealloc
{
	NSUserDefaultsController *controller = [NSUserDefaultsController sharedUserDefaultsController];

	[controller removeObserver:self forKeyPath:@"values.KTPreferredJPEGQuality"];
	[controller removeObserver:self forKeyPath:@"values.KTSharpeningFactor"];
	[controller removeObserver:self forKeyPath:@"values.KTPrefersPNGFormat"];

	[mySampleImage release];
	
	[super dealloc];
}

- (void)updateImageSettingsBlowAway:(BOOL)aBlowAway;
{
	// PNG FORMAT OR JPEG QUALITY ... BLOW AWAY IMAGE CACHE WHEN CHANGED.
	
	if (nil == mySampleImage)
	{
		// public domain US government image: http://www.nps.gov/archive/prsf/desktop_photo_archive.htm 
		// http://www.nps.gov/archive/prsf/images/desktop/11goldengate.jpg
		// This really shows differences between 100% and 90%, and also shows good artifacts at high compression.
		mySampleImage = [[NSImage imageNamed:@"quality_sample"] retain];
	}
	NSUserDefaultsController *controller = [NSUserDefaultsController sharedUserDefaultsController];
	NSUserDefaults *defaults = [controller defaults];
	
	[oCompressionSample setHidden:NO];
	
	float quality = [defaults floatForKey:@"KTPreferredJPEGQuality"];
	float sharpening = [defaults floatForKey:@"KTSharpeningFactor"];

	CIImage *theCI			= [mySampleImage toCIImage];
	CIImage *sharpenedCI	= [theCI sharpenLuminanceWithFactor:sharpening];
	
	NSImage *sharpenedImage = [sharpenedCI toNSImageBitmap];

	if (![defaults boolForKey:@"KTPrefersPNGFormat"])	// convert to JPEG to show compression
	{
		NSData *jpegData = [sharpenedImage JPEGRepresentationWithCompressionFactor:quality];
		sharpenedImage = [[[NSImage alloc] initWithData:jpegData] autorelease];
		[sharpenedImage normalizeSize];
	}
	[oCompressionSample setImage:sharpenedImage];
	
}


// Scale down if it's bigger than 150% of what will show.  That will allow us to drag in approximately sized
// small images for an exact test.

- (IBAction) updateSampleImage:sender		
{
#define SAMPLE_WIDTH 100
#define SAMPLE_HEIGHT 75

	[mySampleImage release];
	
	NSImage *newImage = [sender image];
	NSBitmapImageRep *bitmap = [newImage bitmap];
	
	if ( [bitmap pixelsWide] > (1.5 * SAMPLE_WIDTH) || [bitmap pixelsHigh] > (1.5 * SAMPLE_WIDTH) )
	{
		CIImage *im = [newImage toCIImage];
		// Show the top/center of the image.  This crop & center it.
		im = [im scaleToWidth:SAMPLE_WIDTH height:SAMPLE_HEIGHT behavior:kCoverRect alignment:NSImageAlignCenter opaqueEdges:YES];
		
		newImage = [im toNSImageBitmap];
	}
	mySampleImage = [newImage retain];
	[self updateImageSettingsBlowAway:NO];
}

- (void)windowDidLoad
{
	[super windowDidLoad];

	NSUserDefaultsController *controller = [NSUserDefaultsController sharedUserDefaultsController];

	[controller addObserver:self forKeyPath:@"values.KTPreferredJPEGQuality" options:(NSKeyValueObservingOptionNew) context:nil];

	[controller addObserver:self forKeyPath:@"values.KTSharpeningFactor" options:(NSKeyValueObservingOptionNew) context:nil];
	[controller addObserver:self forKeyPath:@"values.KTPrefersPNGFormat" options:(NSKeyValueObservingOptionNew) context:nil];

	// Now start observing
	
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

	if ([aKeyPath isEqualToString:@"sparkleOption"])
	{
		[super observeValueForKeyPath:aKeyPath ofObject:anObject change:aChange context:aContext];
	}
	else
	{
		[self updateImageSettingsBlowAway:(nil != aKeyPath)];
	}
}


@end
