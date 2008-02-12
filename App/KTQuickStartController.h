//
//  KTQuickStartController.h
//  Marvel
//
//  Created by Terrence Talbot on 1/6/06.
//  Copyright 2006 Biophony LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QTKit/QTKit.h>

@interface KTQuickStartController : NSWindowController {

	IBOutlet NSButton *oHighLink;
	IBOutlet NSButton *oLowLink;
	IBOutlet QTMovieView *oPreviewMovie;

	float myOpacity;
}

- (void) doWelcomeAlert:(id)bogus;
- (IBAction) openLicensing:(id)sender;
- (IBAction) openIntro:(id)sender;
- (IBAction) openHigh:(id)sender;
- (IBAction) openLow:(id)sender;
- (IBAction) done:(id)sender;
+ (id)sharedController;

@end
