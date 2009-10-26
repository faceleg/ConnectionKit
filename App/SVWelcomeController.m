//
//  KTPlaceholderController.m
//  Marvel
//
//  Created by Dan Wood on 10/16/06.
//  Copyright 2006-2009 Karelia Software. All rights reserved.
//

#import "SVWelcomeController.h"

#import "NSColor+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSThread+Karelia.h"
#import <QTKit/QTKit.h>
#import "KSLicensedAppDelegate.h"
#import "KSNetworkNotifier.h"
#import "KSYellowStickyWindow.h"
#import "Registration.h"
#import "NSDate+Karelia.h"
#import "NSURL+Karelia.h"
#import "CIImage+Karelia.h"
#import <QuickLook/QuickLook.h>
#import <QuartzCore/QuartzCore.h>
#import "KTDocument.h"

enum { LICENSED = 0, UNDISCLOSED, DISCLOSED, NO_NETWORK };


@interface NSURL(PlaceholderTable)
- (NSAttributedString *)resourceAttributedTitleAndDescription;
- (NSImage *)resourcePreviewImage;
@end
@implementation NSURL(PlaceholderTable)

- (NSAttributedString *)resourceAttributedTitleAndDescription
{
	NSString *displayName = [self displayName];
	
	NSMutableString *desc = [NSMutableString string];	// METADATA -- CAN WE PUT IN TITLE/SUBTITLE?  NOT GETTING SAVED?

	NSError *err = nil;
	NSURL *datastoreURL = [KTDocument datastoreURLForDocumentURL:self type:nil];
	NSDictionary *values =[NSPersistentStoreCoordinator
						   metadataForPersistentStoreOfType:NSSQLiteStoreType
						   URL:datastoreURL
						   error:&err];

	id value = nil;
	enum { kNone, kTitle, kPages, kDate };
	int lastAppendedItem = kNone;
	if (value = [values objectForKey:(NSString*)kMDItemTitle])
	{
		if (![displayName isEqualToString:value] && ![displayName hasPrefix:value])
		{
			[desc appendFormat:@"%C%@%C", 0x201C, value, 0x201D];	// only append if not equal, or a substring of file title
			lastAppendedItem = kTitle;
		}
	}
	
	if (value = [values objectForKey:(NSString*)kMDItemNumberOfPages])
	{
		if ([desc length]) [desc appendString:@" "];	// just a space to separate page count
		if ([value intValue] > 1)
		{
			[desc appendFormat:@"%@ Pages", value];	// only show if > 1 pages.  (Bypasses pluralization issue as a side benefit)
			lastAppendedItem = kPages;
	}
	}

	// Spotlight only, not in document metadata
	CFStringRef filePath = (CFStringRef)[self path];
	MDItemRef mdItem = MDItemCreate(NULL, filePath);
	
	values = NSMakeCollectable(MDItemCopyAttributeList(mdItem,kMDItemLastUsedDate) );
	[values autorelease];
	if (value = [values objectForKey:(NSString*)kMDItemLastUsedDate])
	{
		switch (lastAppendedItem)
		{
			case kTitle: [desc appendString:@" "]; break;
			case kPages:  [desc appendString:@", "]; break;
			default: break;
		}
		NSDate *date = (NSDate *)value;
		
		[desc appendFormat:@"Opened %@", [date relativeFormatWithStyle:NSDateFormatterShortStyle]];
		lastAppendedItem = kDate;
	}
	
	NSDictionary *attr1 = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:[NSFont systemFontSize]], NSFontAttributeName, nil];
	NSDictionary *attr2 = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:[NSFont labelFontSize]], NSFontAttributeName, 
						   [NSColor grayColor], NSForegroundColorAttributeName, nil];
	
	NSMutableAttributedString *attrStickyText = [[[NSMutableAttributedString alloc] initWithString:
												  displayName attributes:attr1] autorelease];	
	[attrStickyText appendAttributedString:[[[NSAttributedString alloc] initWithString:@"\n" attributes:attr1] autorelease]];
	[attrStickyText appendAttributedString:[[[NSAttributedString alloc] initWithString:desc attributes:attr2] autorelease]];
	return attrStickyText;
}

- (NSImage *)resourcePreviewImage;		// Get quicklook thumbnail, crop off bottom, and give it a bit of an outline
{
	const int thumbSize = 58;
	const int thumbHeight = 46;	// only show the top pixels so we don't get the "SANDVOX" embossed
	CGImageRef cgimage = nil;
	NSImage *result = nil;
	
	CGSize size = CGSizeMake(thumbSize,thumbSize);
	cgimage = QLThumbnailImageCreate(kCFAllocatorDefault,(CFURLRef)self,size,NULL);
	
	if (cgimage)
	{
		NSSize size = NSZeroSize;
		size.width = CGImageGetWidth(cgimage);
		size.height = CGImageGetWidth(cgimage);
		
		CIImage *ci = [CIImage imageWithCGImage:cgimage];
		CGImageRelease(cgimage);
		ci = [ci imageByCroppingToSize:CGSizeMake(thumbSize,thumbHeight) alignment:NSImageAlignTop];
		ci = [ci addShadow:1];
		result = [ci toNSImage];
	}
	if (!result)
	{
		result = [[NSWorkspace sharedWorkspace] iconForFile:[self path]];
	}
	return result;
}


@end

@implementation SVWelcomeController

@synthesize sticky = _sticky;
@synthesize networkAvailable = _networkAvailable;

- (id)init
{
    self = [super initWithWindowNibName:@"Welcome"];
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

- (void) updateNetworkStatus:(NSNotification *)aNotification
{
	self.networkAvailable = [KSNetworkNotifier isNetworkAvailable];
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

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateNetworkStatus:) name:kKSNetworkIsAvailableNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateNetworkStatus:) name:kKSNetworkIsNotAvailableNotification object:nil];
		
	
	[self updateLicenseStatus:nil];
	[self updateNetworkStatus:nil];

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

- (IBAction) openScreencast:(id)sender;
{
	[[NSApp delegate] openScreencast:nil];
}

- (IBAction) showHelp:(id)sender
{
	[[NSApp delegate] showHelpPage:@"Discover"];	// HELPSTRING
}




@end
