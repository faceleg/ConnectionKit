//
//  SVCommentsWindowController.m
//  Sandvox
//
//  Created by Terrence Talbot on 11/1/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVCommentsWindowController.h"
#import "Debug.h"
#import "KTMaster.h"

@implementation SVCommentsWindowController

- (void)setMaster:(KTMaster *)master
{
    if ( [self window] )
    {
        [objectController setContent:master];
    }
}

- (void)configureComments:(NSWindowController *)sender;
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
    [objectController setContent:nil];
}

- (IBAction)closeSheet:(id)sender
{
    [NSApp endSheet:[self window]];
}

@end
