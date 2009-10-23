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


@interface KTPlaceholderController : KSSingletonWindowController {

	IBOutlet NSView *oStickyView;
	IBOutlet NSView *oStickyRotatedView;
	IBOutlet NSTextView *oStickyTextView;
	IBOutlet NSButton *oStickyButton;

	IBOutlet NSArrayController *oRecentDocsController;
	
@private
	KSYellowStickyWindow *_sticky;
	
}

@property (retain) KSYellowStickyWindow *sticky;

- (IBAction) doNew:(id)sender;
- (IBAction) doOpen:(id)sender;
- (IBAction) openLicensing:(id)sender;
- (IBAction) openScreencastLargeSize:(id)sender;
- (IBAction) openScreencastSmallSize:(id)sender;
- (IBAction) disclose:(id)sender;

@end
