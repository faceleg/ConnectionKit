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
#import "NSString+Karelia.h"
#import "NSFileManager+Karelia.h"
#import "NSURL+Karelia.h"
#import "NSArray+Karelia.h"
#import "CIImage+Karelia.h"
#import <QuickLook/QuickLook.h>
#import <QuartzCore/QuartzCore.h>
#import "KTDocument.h"

static NSArray *sRecentDocumentURLs = nil;	// singleton object for URL display to consult.
static NSMutableDictionary *sRecentDocumentURLTextCache = nil;
static NSMutableDictionary *sRecentDocumentURLImageCache = nil;

@interface NSURL(PlaceholderTable)
- (NSAttributedString *)resourceAttributedTitleAndDescription;
- (NSImage *)resourcePreviewImage;
@end
@implementation NSURL(PlaceholderTable)

/* Looks at URL list, ignores itself, but finds any other URLs with the same file title but in a different
 directory,  Extracts the different parts of the path, so we can identify which version it is
 */
- (NSString *)differentDirectoryComparedToAllURLs:(NSArray *)allURLs
{
	NSString *result = nil;
	NSString *myPath = [self path];
	NSString *myFile = [myPath lastPathComponent];
	NSString *myDir = [myPath stringByDeletingLastPathComponent];
	for (NSURL *url in allURLs)
	{
		NSString *path = [url path];
		if (![path isEqualToString:myPath])		// different path?
		{
			NSString *file = [path lastPathComponent];
			if ([file isEqualToString:myFile])	// same file name? 
			{
				NSString *dir = [path stringByDeletingLastPathComponent];
				// Now find what's different between dir and myDir
				NSString *commonPrefix = [myDir commonPrefixWithString:dir options:NSCaseInsensitiveSearch];
				NSRange keep = NSMakeRange([commonPrefix length], [myDir length] - [commonPrefix length]);
				NSString *differentPart = [myDir substringWithRange:keep];
				NSArray *uniquePathComponents = [differentPart pathComponents];
				result = [uniquePathComponents firstObjectKS];	// just show highest level folder
				break;	// we found what's unique about this file so stop searching
					// Yes, there might be some other higher level folder if we keep looking
					// but the odds of so many files with the same names are really low, and
					// we can only do so much to help people distinguish them.
			}
		}
	}
	return result;
}

- (NSAttributedString *)resourceAttributedTitleAndDescription
{
	NSAttributedString *cachedText = [sRecentDocumentURLTextCache objectForKey:self];
	if (!cachedText)
	{
		NSString *displayName = [self displayName];
		
		NSMutableString *desc = [NSMutableString string];	// METADATA -- CAN WE PUT IN TITLE/SUBTITLE?  NOT GETTING SAVED?

		NSString *differenceInPaths = [self differentDirectoryComparedToAllURLs:sRecentDocumentURLs];
		
		NSError *err = nil;
		NSURL *datastoreURL = [KTDocument datastoreURLForDocumentURL:self type:nil];
		NSDictionary *values =[NSPersistentStoreCoordinator
							   metadataForPersistentStoreOfType:NSSQLiteStoreType
							   URL:datastoreURL
							   error:&err];

		id value = nil;
		enum { kNone, kTitle, kWhere, kPages, kDate };
		int lastAppendedItem = kNone;
		
		// Document title (if unique from file name)
		
		if (value = [values objectForKey:(NSString*)kMDItemTitle])
		{
			// If the title only differs from the filename by _ characters, don't bother showing the title!
			NSString *displayNameReplacingUnderscores = [displayName stringByReplacing:@"_" with:@" "];
			if (![displayNameReplacingUnderscores isEqualToString:value] && ![displayNameReplacingUnderscores hasPrefix:value])
			{
				[desc appendFormat:NSLocalizedString(@"\\U201C%@\\U201D", @"quotes around the document name"), value];	// only append if not equal, or a substring of file title
				lastAppendedItem = kTitle;
			}
		}

		// Where -- unique folder, in case title same as other ones in the list
		NSRange rangeToBold = NSMakeRange(NSNotFound, 0);
		
		if (nil != differenceInPaths)
		{
			if ([desc length]) [desc appendString:@" "];	// just a space to separate
			NSString *folderFormatString = NSLocalizedString(@"in %@", @"Indicator what directory the file is found in, thus it is ''in <foldername>''");
			// We will do our own manual substitution of the %@ so we can also bold it.
			NSRange whereMarker = [folderFormatString rangeOfString:@"%@"];
			if (NSNotFound != whereMarker.location)
			{
				NSString *replaced = [folderFormatString stringByReplacing:@"%@" with:differenceInPaths];
				NSUInteger lengthSoFar = [desc length];
				[desc appendString:replaced];
				rangeToBold = NSMakeRange(lengthSoFar+whereMarker.location, [differenceInPaths length]);
				lastAppendedItem = kWhere;
			}
		}
		
		
		// Number of pages, if > 1 page
		
		if (value = [values objectForKey:(NSString*)kMDItemNumberOfPages])
		{
			switch (lastAppendedItem)
			{
				case kNone: break;
				case kTitle: [desc appendString:@" "]; break;
				default:  [desc appendString:@", "]; break;
			}
			if ([value intValue] > 1)
			{
				[desc appendFormat:@"%@ pages", value];	// only show if > 1 pages.  (Bypasses pluralization issue as a side benefit)
				lastAppendedItem = kPages;
			}
		}

		// Last Opened Date
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
			
			[desc appendFormat:@"opened %@", [date relativeFormatWithStyle:NSDateFormatterShortStyle]];
			lastAppendedItem = kDate;
		}
		
		NSFont *font1 = [NSFont systemFontOfSize:[NSFont systemFontSize]];
		NSFont *font2 = [NSFont systemFontOfSize:[NSFont labelFontSize]];
		NSFont *font2bold = [[NSFontManager sharedFontManager] convertFont:font2 toHaveTrait:NSBoldFontMask];
		
		NSMutableParagraphStyle *paraStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
		[paraStyle setParagraphStyle:[NSParagraphStyle defaultParagraphStyle]];
		[paraStyle setLineBreakMode:NSLineBreakByTruncatingTail];
		[paraStyle setTighteningFactorForTruncation:0.1];
		 
		 NSDictionary *attr1 = [NSDictionary dictionaryWithObjectsAndKeys:font1, NSFontAttributeName, 
								paraStyle, NSParagraphStyleAttributeName, 
								nil];
		 NSDictionary *attr2 = [NSDictionary dictionaryWithObjectsAndKeys:font2, NSFontAttributeName, 
								[NSColor darkGrayColor], NSForegroundColorAttributeName, nil];
		 
		NSMutableAttributedString *attrStickyText = [[[NSMutableAttributedString alloc] initWithString:
													  displayName attributes:attr1] autorelease];	
		[attrStickyText appendAttributedString:[[[NSAttributedString alloc] initWithString:@"\n" attributes:attr1] autorelease]];
		
		NSMutableAttributedString *extraInfo = [[[NSMutableAttributedString alloc] initWithString:desc attributes:attr2] autorelease];
		if (NSNotFound != rangeToBold.location)
		{
			[extraInfo addAttributes:[NSDictionary dictionaryWithObjectsAndKeys:font2bold, NSFontAttributeName, nil] range:rangeToBold];
		}
		
		[attrStickyText appendAttributedString:extraInfo];
		cachedText = [[attrStickyText copy] autorelease];
		[sRecentDocumentURLTextCache setObject:cachedText forKey:self];
	}
	return cachedText;
}

- (NSImage *)resourcePreviewImage;		// Get quicklook thumbnail, crop off bottom, and give it a bit of an outline
{
	NSImage *cachedImage = [sRecentDocumentURLImageCache objectForKey:self];
	if (!cachedImage)
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
		cachedImage = result;
		[sRecentDocumentURLImageCache setObject:result forKey:self];
	}
	return cachedImage;
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
	[sRecentDocumentURLs release];			sRecentDocumentURLs = nil;
	[sRecentDocumentURLTextCache release];	sRecentDocumentURLTextCache = nil;
	[sRecentDocumentURLImageCache release]; sRecentDocumentURLImageCache = nil;
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}



- (void) updateLicenseStatus:(NSNotification *)aNotification
{
	if (nil != gRegistrationString )
	{
		[self.sticky.animator setAlphaValue:0.0];	// animate to hidden
	}
	else
	{
		[self.sticky.animator setAlphaValue:1.0];	// animate open
	}
}

- (void) updateNetworkStatus:(NSNotification *)aNotification
{
	self.networkAvailable = [KSNetworkNotifier isNetworkAvailable];
}

- (IBAction)showWindow:(id)sender;
{
	NSRect separatorFrame = [oRecentBox frame];
	
	NSArray *recentDocs = [oRecentDocsController content];
	if ([recentDocs count])
	{
		[[self window] setContentSize:NSMakeSize(NSMaxX(separatorFrame), NSHeight([[self window] frame]))];
	}
	else
	{
		[[self window] setContentSize:NSMakeSize(NSMinX(separatorFrame)-1, NSHeight([[self window] frame]))];
	}
	[super showWindow:sender];
}

- (void) setupStickyWindow
{
	if (!_sticky)
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
		[_sticky setAlphaValue:0.0];		// initially ZERO ALPHA!

		NSRect separatorFrame = [oRecentBox frame];
		NSPoint convertedWindowOrigin;
		if ([[oRecentDocsController content] count])
		{
			convertedWindowOrigin = NSMakePoint(NSMaxX(separatorFrame)-80,300);
		}
		else
		{
			convertedWindowOrigin = NSMakePoint(NSMinX(separatorFrame)-80,400);
		}		
		[_sticky setFrameTopLeftPoint:[[self window] convertBaseToScreen:convertedWindowOrigin]];
		
		[[self window] addChildWindow:_sticky ordered:NSWindowAbove];
	}
}

- (void)windowDidLoad
{
    [super windowDidLoad];

	[oRecentDocumentsTable setDoubleAction:@selector(openSelectedRecentDocument:)];
	[oRecentDocumentsTable setTarget:self];
	[oRecentDocumentsTable setIntercellSpacing:NSMakeSize(0,3.0)];	// get the columns closer together
	
	NSArray *urls = [[NSDocumentController sharedDocumentController] recentDocumentURLs];
#if 0
	// TESTING HARNESS ... I HAVE A BUNCH OF DOCUMENTS IN THERE.
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *dir = [@"~/Desktop/Sites" stringByExpandingTildeInPath];
	NSArray *files = [fm contentsOfDirectoryAtPath:dir error:nil];
	NSMutableArray *localURLs = [NSMutableArray array];
	for (NSString *filename in files)
	{
		if (![filename hasPrefix:@"."])
		{
			NSString *path = [dir stringByAppendingPathComponent:filename];
			NSURL *url = [NSURL fileURLWithPath:path];
			[localURLs addObject:url];
		}
	}
	urls = [NSArray arrayWithArray:localURLs];
#endif
	
#if 0
	// Test for having ZERO recent documents.
	urls = [NSArray array];
#endif
	
	if ([urls count])
	{
		[oRecentDocsController setContent:urls];
	}
	
	// Set up our storage for speeding up display of these recent documents.  Otherwise it's very sluggish.
	sRecentDocumentURLs = [urls retain];
	sRecentDocumentURLTextCache = [[NSMutableDictionary alloc] init];
	sRecentDocumentURLImageCache = [[NSMutableDictionary alloc] init];
	
	
	[oRecentDocsController setSelectionIndexes:[NSIndexSet indexSet]];

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

	[[self window] setContentBorderThickness:50.0 forEdge:NSMinYEdge];	// have to do in code until 10.6

}

// Attach sticky here becuase it seems we can only really make this child window appear when the window
// is already appearing, and I don't see a notification for window-did-show.  We don't want to orderFront
// the sticky window because that's weird if our welcome window is not in front.
- (void)windowDidBecomeKey:(NSNotification *)notification
{
	[self setupStickyWindow];
	[self updateLicenseStatus:nil];
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

- (IBAction) openSelectedRecentDocument:(id)sender;
{
	id sel = [oRecentDocsController selection];
	NSURL *fileURL = [sel valueForKey:@"self"];

	NSError *localError = nil;
	KTDocument *doc = nil;
	NSDocumentController *controller = [NSDocumentController sharedDocumentController];
	@try
	{
		doc = [controller openDocumentWithContentsOfURL:fileURL display:YES error:&localError];
	}
	@catch (NSException *exception)
	{
		LOG((@"open document (%@) threw %@", fileURL, exception));
		
		// COPIED FROM APP DELEGATE CODE -- LET'S ASSUME WE WANT TO HANDLE ERRORS THE SAME WAY.
		
		// Apple bug, I think -- if it couldn't open it, it is in some weird open state even though we didn't get it.
		// So get the document pointer from the URL.
		KTDocument *previouslyOpenDocument = (KTDocument *)[controller documentForURL:fileURL];
		if (nil != previouslyOpenDocument)
		{
			// remove its window controller
			NSWindowController *windowController = (NSWindowController *)[previouslyOpenDocument mainWindowController];
			if (nil != windowController)
			{
				[previouslyOpenDocument removeWindowController:windowController];
			}
			[previouslyOpenDocument close];
			previouslyOpenDocument = nil;
		}
		
		[NSApp reportException:exception];
	}
	
	if ( nil != localError )
	{
		[[NSApplication sharedApplication] presentError:localError];
	}
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

- (NSString *)tableView:(NSTableView *)aTableView toolTipForCell:(NSCell *)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation
{
	NSURL *url = [[oRecentDocsController arrangedObjects] objectAtIndex:row];
	NSString *path = [url path];
	NSString *displayPath = [[NSFileManager defaultManager] displayPathAtPath:path];

	return displayPath;
}



@end
