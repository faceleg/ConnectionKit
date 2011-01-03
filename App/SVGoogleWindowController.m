//
//  SVGoogleWindowController.m
//  Sandvox
//
//  Created by Terrence Talbot on 11/1/10.
//  Copyright 2010-11 Karelia Software. All rights reserved.
//

#import "SVGoogleWindowController.h"
#import "Debug.h"
#import "KTSite.h"


@implementation SVGoogleWindowController

@synthesize objectController = _objectController;

- (void)dealloc
{
    self.objectController = nil;
    [super dealloc];
}

- (void)setSite:(KTSite *)site
{
    if ( [self window] )
    {
        [self.objectController setContent:site];
    }
}

- (void)configureGoogle:(NSWindowController *)sender;
{
    [NSApp beginSheet:[self window] 
       modalForWindow:[sender window] 
        modalDelegate:self 
       didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) 
          contextInfo:NULL];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
{
    if ( ![sheet makeFirstResponder:sheet] )
    {
        [sheet endEditingFor:nil];
    }    
    [[self window] orderOut:nil];
    [self.objectController setContent:nil];
}

- (IBAction)closeSheet:(id)sender
{
    [NSApp endSheet:[self window]];
}

@end
