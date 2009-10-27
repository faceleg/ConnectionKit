//
//  KTPlaceholderController.h
//  Marvel
//
//  Created by Dan Wood on 10/16/06.
//  Copyright 2006-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KSSingletonWindowController.h"

@class QTMovieView, KSYellowStickyWindow;


@interface SVWelcomeController : KSSingletonWindowController {

	IBOutlet NSView *oStickyView;
	IBOutlet NSView *oStickyRotatedView;
	IBOutlet NSTextView *oStickyTextView;
	IBOutlet NSButton *oStickyButton;

	IBOutlet NSArrayController *oRecentDocsController;
	
@private
	BOOL _networkAvailable;
	KSYellowStickyWindow *_sticky;
	
}

@property (retain) KSYellowStickyWindow *sticky;
@property (assign) BOOL networkAvailable;

- (IBAction) doNew:(id)sender;
- (IBAction) doOpen:(id)sender;
- (IBAction) openLicensing:(id)sender;
- (IBAction) openScreencast:(id)sender;
- (IBAction) showHelp:(id)sender;

@end
