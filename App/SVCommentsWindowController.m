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
#import "NSAttributedString+Karelia.h"


@implementation SVCommentsWindowController
@synthesize objectController = _objectController;
@synthesize disqusOverview = _disqusOverview;
@synthesize intenseDebateOverview = _intenseDebateOverview;
@synthesize facebookCommentsOverview = _facebookCommentsOverview;

- (void)windowDidLoad
{
    // localize NSTextViews
    
    // Disqus
    NSString *localizedStringWithBrackets = NSLocalizedString(@"Enter your [Disqus] shortname to enable comments on this site.", @"The [ and the ] will be removed, and the text in between will be give a hyperlink attribute. PLEASE VISIT THIS SITE TO GET THE EXACT TRANSLATION OF THE QUOTED STRING --> http://disqus.com/");
    NSAttributedString *hyperlinkedString = [NSAttributedString systemFontStringWithString:localizedStringWithBrackets 
                                                                     hyperlinkInBracketsTo:[NSURL URLWithString:@"http://disqus.com/"]];
    NSAssert(nil != self.disqusOverview, @"no outlet");
    [[self.disqusOverview textStorage] setAttributedString:hyperlinkedString];

    // IntenseDebate
    localizedStringWithBrackets = NSLocalizedString(@"Enter your [IntenseDebate] Account ID to enable comments on this site.", @"The [ and the ] will be removed, and the text in between will be give a hyperlink attribute. PLEASE VISIT THIS SITE TO GET THE EXACT TRANSLATION OF THE QUOTED STRING --> http://intensedebate.com/");
    hyperlinkedString = [NSAttributedString systemFontStringWithString:localizedStringWithBrackets 
                                                 hyperlinkInBracketsTo:[NSURL URLWithString:@"http://intensedebate.com/"]];
    NSAssert(nil != self.intenseDebateOverview, @"no outlet");
    [[self.intenseDebateOverview textStorage] setAttributedString:hyperlinkedString];
    
    // Facebook Comments
    localizedStringWithBrackets = NSLocalizedString(@"Enter your site’s [Facebook] App ID to enable comments on this site.", @"The [ and the ] will be removed, and the text in between will be give a hyperlink attribute. PLEASE VISIT THIS SITE TO GET THE EXACT TRANSLATION OF THE QUOTED STRING --> http://www.facebook.com/");
    hyperlinkedString = [NSAttributedString systemFontStringWithString:localizedStringWithBrackets 
                                                 hyperlinkInBracketsTo:[NSURL URLWithString:@"http://www.facebook.com/"]];
    NSAssert(nil != self.facebookCommentsOverview, @"no outlet");
    [[self.facebookCommentsOverview textStorage] setAttributedString:hyperlinkedString];
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
    [KSWORKSPACE attemptToOpenWebURL:[NSURL URLWithString:@"http://disqus.com/admin/register/"]];
}

- (IBAction)visitFacebook:(id)sender
{
    [KSWORKSPACE attemptToOpenWebURL:[NSURL URLWithString:@"http://developers.facebook.com/setup/"]];
}

- (IBAction)visitIntenseDebate:(id)sender
{
    [KSWORKSPACE attemptToOpenWebURL:[NSURL URLWithString:@"http://intensedebate.com/signup"]];
}

@end
