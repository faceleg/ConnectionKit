//
//  KTPrefsController.h
//  Marvel
//
//  Copyright (c) 2005 Biophony LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface KTPrefsController : NSWindowController
{
	IBOutlet NSImageView *oCompressionSample;
	IBOutlet NSObjectController *oObjectController;
	
	NSImage *mySampleImage;
}

+ (KTPrefsController *)sharedPrefsController;
- (IBAction) windowHelp:(id)sender;

@end

