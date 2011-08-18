//
//  SVWelcomeController.h
//  Marvel
//
//  Created by Dan Wood on 10/16/06.
//  Copyright 2006-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KSSingletonWindowController.h"

@class QTMovieView, KSYellowStickyWindow;


@interface SVWelcomeController : KSSingletonWindowController {

	IBOutlet NSView *oStickyView;
	IBOutlet NSView *oStickyRotatedView;
	IBOutlet NSTextView *oStickyTextView;
	IBOutlet NSButton *oStickyButton;
	IBOutlet NSButton *oOpenSelectedButton;
	IBOutlet NSTableView *oRecentDocumentsTable;

	IBOutlet NSBox *oRecentBox;

	IBOutlet NSArrayController *oRecentDocsController;
	
@private
	BOOL _networkAvailable;
	KSYellowStickyWindow *_sticky;
	NSArray *_recentDocuments;
}

@property (nonatomic, retain) KSYellowStickyWindow *sticky;
@property (nonatomic, copy) NSArray *recentDocuments;
@property (assign) BOOL networkAvailable;

// Match the selectors used by NSDocumentController when possible so that actions from menu bar items gets directed to us if the panel is main/key
- (IBAction)openDocument:(id)sender;
- (IBAction)openSelectedRecentDocument:(id)sender;
#ifndef MAC_APP_STORE
- (IBAction)openLicensing:(id)sender;
#endif
- (IBAction)openScreencast:(id)sender;
- (IBAction)showDiscoverHelp:(id)sender;

- (void)showWindowAndBringToFront:(BOOL)bringToFront initial:(BOOL)firstTimeSoReopenSavedDocuments;

@end
