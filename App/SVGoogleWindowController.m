//
//  SVGoogleWindowController.m
//  Sandvox
//
//  Created by Terrence Talbot on 11/1/10.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVGoogleWindowController.h"
#import "Debug.h"
#import "KTSite.h"
#import "KSAppDelegate.h"


@implementation SVGoogleWindowController

@synthesize objectController = _objectController;
@synthesize verificationCodeField = _verificationCodeField;
@synthesize analyticsCodeField = _analyticsCodeField;

- (void)dealloc
{
    self.objectController = nil;
    self.verificationCodeField = nil;
    self.analyticsCodeField = nil;
    [super dealloc];
}

- (void)windowDidLoad
{
    // figure out our best possible mono-spaced font
    // (this somewhat mimics -[NSTextView defaultTextAttributes])
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *fontName = [defaults objectForKey:@"HTMLViewFontName"];
    float pointSize = [defaults floatForKey:@"HTMLViewPointSize"];
    
    NSFont *font = nil;
    if ( fontName )
    {
        font = [NSFont fontWithName:fontName size:pointSize];
    }
    if (!font)
    {
        // For some reason, Snow Leopard gives us Menlo but doesn't use it by default!
        NSFont *menlo = [NSFont fontWithName:@"Menlo-Regular" size:12.0];
        if (menlo)
        {
            [NSFont setUserFixedPitchFont:menlo];
        }
        font = [NSFont userFixedPitchFontOfSize:12.0];
    }
    
    [self.verificationCodeField setFont:font];
    [self.analyticsCodeField setFont:font];    
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
    [[NSApp delegate] showHelpPage:@"Google_Integration"];    // HELPSTRING
}

@end
