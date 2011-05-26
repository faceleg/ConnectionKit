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
#import "NSAttributedString+Karelia.h"

@implementation SVGoogleWindowController

@synthesize objectController = _objectController;
@synthesize verificationCodeField = _verificationCodeField;
@synthesize analyticsCodeField = _analyticsCodeField;
@synthesize verificationOverview = _verificationOverview;
@synthesize analyticsOverview = _analyticsOverview;

- (void)dealloc
{
    self.objectController = nil;
    self.verificationCodeField = nil;
    self.analyticsCodeField = nil;
	self.verificationOverview = nil;
	self.analyticsOverview = nil;
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
	

	NSString *ver0 = NSLocalizedString(@"Visit [Google Webmaster Tools] to register and verify your site using the “Add a meta tag to your site’s home page” option. Paste the provided tag below and then publish your website to confirm verification.", @"The [ and the ] will be removed, and the text in between will be give a hyperlink attribute.  PLEASE VISIT THIS SITE TO GET THE EXACT TRANSLATION OF THE QUOTED STRING --> http://www.google.com/webmasters/tools/");
	NSAttributedString *ver1 = [NSAttributedString systemFontStringWithString:ver0 hyperlinkInBracketsTo:
								[NSURL URLWithString:@"http://www.google.com/webmasters/tools/"]];
	[[self.verificationOverview textStorage] setAttributedString:ver1];

 
	NSString *ana0 = NSLocalizedString(@"Visit [Google Analytics] to add a profile for your website. Paste the provided code below and then publish your website to begin tracking.", @"The [ and the ] will be removed, and the text in between will be give a hyperlink attribute.");
	NSAttributedString *ana1 = [NSAttributedString systemFontStringWithString:ana0 hyperlinkInBracketsTo:
								[NSURL URLWithString:@"http://www.google.com/analytics/"]];
	[[self.analyticsOverview textStorage] setAttributedString:ana1];
	
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
