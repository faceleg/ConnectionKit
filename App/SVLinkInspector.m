//
//  SVLinkInspector.m
//  Sandvox
//
//  Created by Mike on 10/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVLinkInspector.h"
#import "SVLinkManager.h"
#import "SVLink.h"

#import "KTDocument.h"
#import "KTDocWindowController.h"
#import "KTPage.h"
#import "KSURLFormatter.h"

#import "DOMRange+Karelia.h"


@implementation SVLinkInspector

- (void)loadView
{
    [super loadView];
        
    // Initial setup
    [self refresh];
}

#pragma mark Link

- (void)refresh;
{
    [super refresh];
    
    
    // Make the link field editable if there is nothing entered, or the URL is typed in
    SVLinkManager *manager = [SVLinkManager sharedLinkManager];
    SVLink *link = [manager selectedLink];
    SVLinkType linkType = [link linkType];
    
    switch (linkType)
    {
        case SVLinkToPage:
        {
            // Configure for a local link
            [oLinkSourceView setConnected:YES];
            
            NSString *title = [[link page] title];
            if (!title) title = @"";
            [oLinkField setStringValue:title];
            
            break;
        }
        case SVLinkExternal:
        {
            // Configure for a generic link
            [oLinkSourceView setConnected:NO];
            
            NSString *title = [link URLString];
            if (!title) title = @"";
            [oLinkField setStringValue:title];
            
            break;
        }
        default:
            break;
    }
    
    
    [oLinkTypePopUpButton selectItemWithTag:linkType];
    [oTabView selectTabViewItemAtIndex:[oLinkTypePopUpButton indexOfSelectedItem]];
    
    [oOpenInNewWindowCheckbox setState:([link openInNewWindow] ? NSOnState : NSOffState)];
}

- (SVLinkManager *)linkManager
{
    // Exposed only here for the benefit of bindings
    return [SVLinkManager sharedLinkManager];
}

#pragma mark UI Actions

- (IBAction)selectLinkType:(NSPopUpButton *)sender;
{
    SVLinkType type = [sender selectedTag];
    if (type == 0)
    {
        [[SVLinkManager sharedLinkManager] modifyLinkTo:nil];
    }
    else if (type == SVLinkExternal)
    {
        SVLink *link = [[SVLinkManager sharedLinkManager] guessLink];
        if (link) [[SVLinkManager sharedLinkManager] modifyLinkTo:link];
    }
    else if (type == SVLinkToFullSizeImage)
    {
        SVLink *link = [[SVLink alloc] initLinkToFullSizeImageOpensInNewWindow:NO];
        [[SVLinkManager sharedLinkManager] modifyLinkTo:link];
        [link release];
    }
    
    [oTabView selectTabViewItemAtIndex:[sender indexOfSelectedItem]];
}

- (void)linkSourceConnectedTo:(KTPage *)aPage;
{
	if (aPage)
	{
		SVLink *link = [[SVLink alloc] initWithPage:aPage];
		[[SVLinkManager sharedLinkManager] modifyLinkTo:link];
		[link release];
	}
}

- (IBAction)setLinkURL:(id)sender;
{
    SVLink *link = [[SVLink alloc] initWithURLString:[oLinkField stringValue]
                                     openInNewWindow:[oOpenInNewWindowCheckbox intValue]];
    [[SVLinkManager sharedLinkManager] modifyLinkTo:link];
    [link release];
}

- (IBAction)clearLinkDestination:(id)sender;
{
	//[oLinkLocalPageField setStringValue:@""];
	//[oLinkDestinationField setStringValue:@""];
	//[oLinkLocalPageField setHidden:YES];
	//[oLinkDestinationField setHidden:NO];
	//[oLinkView setConnected:NO];
    
    [[SVLinkManager sharedLinkManager] modifyLinkTo:nil];
}

@end
