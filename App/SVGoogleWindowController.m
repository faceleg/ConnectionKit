//
//  SVGoogleWindowController.m
//  Sandvox
//
//  Created by Terrence Talbot on 11/1/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVGoogleWindowController.h"
#import "Debug.h"

@implementation SVGoogleWindowController

- (void)configureGoogle:(NSWindowController *)sender;
{
    LOG((@"...configure Google..."));
    
    [NSApp beginSheet:[self window] 
       modalForWindow:[sender window] 
        modalDelegate:self 
       didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) 
          contextInfo:NULL];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
{
    [[self window] orderOut:nil];
}

- (IBAction)closeSheet:(id)sender
{
    [NSApp endSheet:[self window]];
}

@end
