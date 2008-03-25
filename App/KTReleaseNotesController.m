//
//  KTReleaseNotesController.m
//  Marvel
//
//  Created by Terrence Talbot on 1/6/06.
//  Copyright 2006 Biophony LLC. All rights reserved.
//

#import "KTReleaseNotesController.h"


@implementation KTReleaseNotesController

/*
+ (id)sharedController;
{
    static id sSharedController = nil;
    if ( nil == sSharedController ) 
    {
        sSharedController = [[self alloc] init];
    }
    
    return sSharedController;
}
*/

- (void)windowDidLoad
{
	// TODO: load the release notes from the net, right?  (Or the bundled release notes in HTML).  If not network, turn off the 'globe' icon for this
    // load ReleaseNotes.rtf
    NSString *path = [[NSBundle mainBundle] pathForResource:@"ReleaseNotes" ofType:@"rtf"];
    (void)[oTextView readRTFDFromFile:path];
    [[self window] setTitle:NSLocalizedString(@"Sandvox Release Notes", "Release Notes Window Title")];
    [[self window] setFrameAutosaveName:@"ReleaseNotesWindow"];    
}

@end
