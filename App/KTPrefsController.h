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
	
	NSImage *mySampleImage;
}

- (IBAction) windowHelp:(id)sender;

@end

