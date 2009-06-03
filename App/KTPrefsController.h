//
//  KTPrefsController.h
//  Marvel
//
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KSSingletonWindowController.h"
#import "KSPrefsController.h"

@class KSEmailAddressComboBox;

@interface KTPrefsController : KSPrefsController
{
	IBOutlet NSImageView *oCompressionSample;
	IBOutlet NSObjectController *oObjectController;

	NSImage *mySampleImage;
}

@end

