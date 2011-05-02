//
//  AppController.h
//  LeopardQuartzComposerTester
//
//  Created by Mike on 28/10/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface AppController : NSObject
{
	NSImage	*myStringImage;
}

- (IBAction)renderFile:(id)sender;

- (NSImage *)stringImage;
- (void)setStringImage:(NSImage *)image;

@end
