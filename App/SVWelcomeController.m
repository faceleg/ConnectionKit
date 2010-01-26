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
#import <QuartzCore/QuartzCore.h>
#import "KTDocument.h"
#import "KSRecentDocument.h"

@interface SVWelcomeController ()

- (void)loadRecentDocumentList;

@end



@implementation SVWelcomeController

@synthesize sticky = _sticky;
@synthesize networkAvailable = _networkAvailable;
@synthesize recentDocuments = _recentDocuments;

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
	
	NSRect contentViewRect = [[self window] contentRectForFrameRect:[[self window] frame]];
	
	[self loadRecentDocumentList];
	NSArray *recentDocs = [oRecentDocsController content];
	
	if ([recentDocs count])
	{
		[[self window] setContentSize:NSMakeSize(NSMaxX(separatorFrame), NSHeight(contentViewRect))];
	}
	else
	{
		[[self window] setContentSize:NSMakeSize(NSMinX(separatorFrame)-1, NSHeight(contentViewRect))];
	}
	[[self window] center];
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

- (void)loadRecentDocumentList;
{
	NSArray *urls = [[NSDocumentController sharedDocumentController] recentDocumentURLs];
#if 0
	// TESTING HARNESS ... I HAVE A BUNCH OF DOCUMENTS IN THERE.
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *dir = [@"~/Subversion/company/KareliaWebSite" stringByExpandingTildeInPath];
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
	
	// Set up our storage for speeding up display of these recent documents.  Otherwise it's very sluggish.
	NSMutableArray *recentDocuments = [NSMutableArray array];
	NSSet *urlSet = [NSSet setWithArray:urls];
	
	for (NSURL *url in urls)
	{
		KSRecentDocument *recentDoc = [[[KSRecentDocument alloc] initWithURL:url allURLs:urlSet] autorelease];
		[recentDocuments addObject:recentDoc];
	}
	self.recentDocuments = [NSArray arrayWithArray:recentDocuments];
	
	[oRecentDocsController setSelectionIndexes:[NSIndexSet indexSet]];
	
}

- (void)windowDidLoad
{
    [super windowDidLoad];

	[oRecentDocumentsTable setDoubleAction:@selector(openSelectedRecentDocument:)];
	[oRecentDocumentsTable setTarget:self];
	[oRecentDocumentsTable setIntercellSpacing:NSMakeSize(0,3.0)];	// get the columns closer together

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(updateLicenseStatus:)
												 name:kKSLicenseStatusChangeNotification
											   object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateNetworkStatus:) name:kKSNetworkIsAvailableNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateNetworkStatus:) name:kKSNetworkIsNotAvailableNotification object:nil];
		
	
	[self updateLicenseStatus:nil];
	[self updateNetworkStatus:nil];

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

- (IBAction)newDocument:(id)sender
{
	[[self window] orderOut:self];
	
    NSError *error;
    if (![[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:&error])
    {
        [self presentError:error
            modalForWindow:[self window]
                  delegate:nil
        didPresentSelector:nil
               contextInfo:NULL];
    }
}

- (IBAction)openDocument:(id)sender
{
	[[self window] orderOut:self];
	[[NSDocumentController sharedDocumentController] openDocument:self];
}

- (IBAction)openSelectedRecentDocument:(id)sender;
{
	KSRecentDocument *recentDoc = [[oRecentDocsController selectedObjects] lastObject];  // should only be a single object selected anyhow
    NSURL *fileURL = [recentDoc URL];

	NSError *error;
	if (![[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:fileURL
                                                                                display:YES
                                                                                  error:&error])
    {
        [self presentError:error
            modalForWindow:[self window]
                  delegate:nil
        didPresentSelector:nil
               contextInfo:NULL];
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
