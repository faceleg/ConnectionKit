//
//  KTPlaceholderController.h
//  Marvel
//
//  Created by Dan Wood on 10/16/06.
//  Copyright 2006 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KSSingletonWindowController.h"

@class QTMovieView;

@interface KTPlaceholderController : KSSingletonWindowController {

	IBOutlet NSButton *oHighLink;
	IBOutlet NSButton *oLowLink;
	IBOutlet QTMovieView *oPreviewMovie;
	IBOutlet NSTextField *oDemoNotification;	// hide if not demo.  Top edge is window bottom.
	IBOutlet id oHideWhenLicensed;				// bring window to this box's top when LICENSED
	IBOutlet id oDisclosureBottom;				// size window to 20 pixels below bottom when DISCLOSED
	IBOutlet id oDisclosureTop;					// size window to top of this when UNDISCLOSED	
}

- (IBAction) doNew:(id)sender;
- (IBAction) doOpen:(id)sender;
- (IBAction) openLicensing:(id)sender;
- (IBAction) openHigh:(id)sender;
- (IBAction) openLow:(id)sender;
- (IBAction) disclose:(id)sender;

@end
