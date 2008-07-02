//
//  KTPrefsController.h
//  Marvel
//
//  Copyright (c) 2005 Biophony LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KSPrefsController.h"

@class KSEmailAddressComboBox;

// TODO: Descend from KSPrefsController (after we are ready to do another round of localization and nib-rebuilding)
@interface KTPrefsController : KSSingletonWindowController
{
	IBOutlet NSImageView *oCompressionSample;
	IBOutlet NSObjectController *oObjectController;
	IBOutlet KSEmailAddressComboBox *oAddressComboBox;

	int mySparkleOption;
	
	NSImage *mySampleImage;

}

- (IBAction) windowHelp:(id)sender;
- (IBAction) checkForUpdates:(id)sender;
- (IBAction) emailComboChanged:(id)sender;

enum { kSparkleNone = 0, kSparkleRelease, kSparkleBeta }; 


@end

