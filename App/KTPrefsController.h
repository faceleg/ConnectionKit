//
//  KTPrefsController.h
//  Marvel
//
//  Copyright (c) 2005 Biophony LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KSSingletonWindowController.h"

@interface KTPrefsController : KSSingletonWindowController
{
	IBOutlet NSImageView *oCompressionSample;
	IBOutlet NSObjectController *oObjectController;
	
	int mySparkleOption;
	
	NSImage *mySampleImage;
}

- (IBAction) windowHelp:(id)sender;
- (IBAction) checkForUpdates:(id)sender;

enum { sparkleNone = 0, sparkleRelease, sparkleBeta }; 

@end

