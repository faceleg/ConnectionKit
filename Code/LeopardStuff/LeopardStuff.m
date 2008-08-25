//
//  LeopardStuff.m
//  LeopardStuff
//
//  Created by Dan Wood on 8/14/08.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "LeopardStuff.h"


@implementation LeopardStuff

// Do the leopard-only version of this. ATSApplicationFontsPath doesn't seem to be working for us.
- (void)loadLocalFontsInBundle:(NSBundle *)aBundle;
{
	NSString *fontsFolder = [aBundle resourcePath];		// make sure this actually works for flat bundles.
	if (fontsFolder)
	{
		NSURL *fontsURL = [NSURL fileURLWithPath:fontsFolder];
		if (fontsURL)
		{
			FSRef fsRef;
			(void)CFURLGetFSRef((CFURLRef)fontsURL, &fsRef);
			
			OSStatus error = ATSFontActivateFromFileReference(&fsRef, kATSFontContextLocal, kATSFontFormatUnspecified, 
													 NULL, kATSOptionFlagsProcessSubdirectories, NULL);
			
			if (noErr != error) NSLog(@"Error %s activating fonts in %@", GetMacOSStatusErrorString(error), aBundle);
		}
	}
}

@end
