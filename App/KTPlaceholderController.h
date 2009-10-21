//
//  KTPlaceholderController.h
//  Marvel
//
//  Created by Dan Wood on 10/16/06.
//  Copyright 2006-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KSSingletonWindowController.h"

@class QTMovieView;

@interface KTColorTextFieldAnimation: NSAnimation
{
	NSColor *myStartColor;
	NSColor *myEndColor;
	NSTextField *myTextField;
}
- (id) initWithStartColor:(NSColor *)aStartColor endColor:(NSColor *)anEndColor textField:(NSTextField *)aTextField;

@end


@interface KTPlaceholderController : KSSingletonWindowController {

	KTColorTextFieldAnimation *myAnimation1;
	KTColorTextFieldAnimation *myAnimation2;

	IBOutlet NSButton *oHighLink;
	IBOutlet NSButton *oLowLink;
	IBOutlet QTMovieView *oPreviewMovie;
	IBOutlet NSTextField *oDemoNotification;	// hide if not demo.  Top edge is window bottom.
	IBOutlet id oHideWhenLicensed;				// bring window to this box's top when LICENSED
	IBOutlet id oDisclosureBottom;				// size window to 20 pixels below bottom when DISCLOSED
	IBOutlet id oDisclosureTop;					// size window to top of this when UNDISCLOSED	
	
	IBOutlet NSArrayController *oRecentDocsController;
}

- (IBAction) doNew:(id)sender;
- (IBAction) doOpen:(id)sender;
- (IBAction) openLicensing:(id)sender;
- (IBAction) openScreencastLargeSize:(id)sender;
- (IBAction) openScreencastSmallSize:(id)sender;
- (IBAction) disclose:(id)sender;

@end
