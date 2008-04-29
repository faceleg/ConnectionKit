//
//  KTReleaseNotesController.m
//  Marvel
//
//  Created by Terrence Talbot on 1/6/06.
//  Copyright 2006 Biophony LLC. All rights reserved.
//

#import "KTReleaseNotesController.h"
#import <Sparkle/Sparkle.h>

@implementation KTReleaseNotesController

- (void)windowDidLoad
{

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *releaseNotesURLString = [defaults objectForKey:SUFeedURLKey];
	
    
	[[self window] setTitle:NSLocalizedString(@"Sandvox Release Notes", "Release Notes Window Title")];
    [[self window] setFrameAutosaveName:@"ReleaseNotesWindow"];    
}

@end
