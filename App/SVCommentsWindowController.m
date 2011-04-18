//
//  SVCommentsWindowController.m
//  Sandvox
//
//  Created by Terrence Talbot on 11/1/10.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVCommentsWindowController.h"
#import "Debug.h"
#import "KTMaster.h"
#import "KSAppDelegate.h"
#import "NSWorkspace+Karelia.h"


@implementation SVCommentsWindowController
@synthesize objectController = _objectController;

- (void)dealloc
{
    self.objectController = nil;
    [super dealloc];
}

- (void)setMaster:(KTMaster *)master
{
    if ( [self window] )
    {
        [self.objectController setContent:master];
    }
}

- (void)configureComments:(NSWindowController *)sender;
{
    if ( ![[self window] isVisible] )
    {
        [NSApp beginSheet:[self window] 
           modalForWindow:[sender window] 
            modalDelegate:self 
           didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) 
              contextInfo:NULL];
    }
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
{
    if ( ![sheet makeFirstResponder:sheet] )
    {
        [sheet endEditingFor:nil];
    }
    [self.objectController setContent:nil];
}

- (IBAction)closeSheet:(id)sender
{
    [NSApp endSheet:[self window]];
    [[self window] orderOut:nil];
}

- (IBAction)windowHelp:(id)sender
{
    [[NSApp delegate] showHelpPage:@"Comments"];    // HELPSTRING
}

- (IBAction)visitDisqus:(id)sender
{
    [[NSWorkspace sharedWorkspace] attemptToOpenWebURL:[NSURL URLWithString:@"http://disqus.com/admin/register/"]];
}

- (IBAction)visitFacebook:(id)sender
{
    [[NSWorkspace sharedWorkspace] attemptToOpenWebURL:[NSURL URLWithString:@"http://developers.facebook.com/setup/"]];
}

- (IBAction)visitIntenseDebate:(id)sender
{
    [[NSWorkspace sharedWorkspace] attemptToOpenWebURL:[NSURL URLWithString:@"http://intensedebate.com/signup"]];
}


@end
