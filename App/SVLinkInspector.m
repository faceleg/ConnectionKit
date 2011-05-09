//
//  SVLinkInspector.m
//  Sandvox
//
//  Created by Mike on 10/01/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVLinkInspector.h"
#import "SVLinkManager.h"
#import "SVLink.h"

#import "KTDocument.h"
#import "KTDocWindowController.h"
#import "KTPage.h"

#import "KSURLFormatter.h"
#import "KSURLUtilities.h"

#import "DOMRange+Karelia.h"


@implementation SVLinkInspector

- (void)awakeFromNib
{
	[oLinkSourceView bind:NSEnabledBinding
				  toObject:self
			   withKeyPath:@"linkManager.editable"
				   options:nil];
	
}

- (void)dealloc
{
	[oLinkSourceView unbind:NSEnabledBinding];
	[super dealloc];
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
        case SVLinkEmail:
            [oEmailAddressField setStringValue:[link targetDescription]];
            break;
            
        case SVLinkExternal:
        {
            // Configure for a generic link
            [oLinkSourceView setConnected:NO];
            
            NSString *urlString = [link URLString];
            if (!urlString) urlString = @"";
            [oLinkField setObjectValue:urlString];
            
            break;
        }
        default:
            break;
    }
    
    
    [oLinkTypePopUpButton selectItemWithTag:linkType];
    
    // When changing away from email, it has nasty tendency to send its action even though nothing has changed. This is unwanted as the user is probably in the middle of changing the selection! So turn, the effect off for a moment.
    [[oEmailAddressField cell] setSendsActionOnEndEditing:NO];
    [oTabView selectTabViewItemAtIndex:[oLinkTypePopUpButton indexOfSelectedItem]];
    [[oEmailAddressField cell] setSendsActionOnEndEditing:YES];
    
    BOOL openInNewWindow = [link openInNewWindow];
    [oExternalLinkOpenInNewWindowCheckbox setState:openInNewWindow];
    [oPageOpenInNewWindowCheckbox setState:openInNewWindow];
    [oImageOpenInNewWindowCheckbox setState:openInNewWindow];
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
        if (link) 
        {
            [[SVLinkManager sharedLinkManager] modifyLinkTo:link];
        }
        else
        {
            // No link could be guessed, so make sure this field is empty.
            // TODO: Would it be better to apply any existing value? might be handy if user wants to make two links to the same address in a row?
            [oLinkField setStringValue:@""];
        }
    }
    else if (type == SVLinkEmail)
    {
        [self setLinkURL:oEmailAddressField];
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
		SVLink *link = [[SVLink alloc] initWithPage:aPage openInNewWindow:[oPageOpenInNewWindowCheckbox intValue]];
		[[SVLinkManager sharedLinkManager] modifyLinkTo:link];
		[link release];
	}
}

- (IBAction)setLinkURL:(id)sender;
{
    NSString *urlString = [sender stringValue];
    
    if ([urlString length] &&
        ![urlString isEqualToString:[[[self linkManager] selectedLink] URLString]])
    {
        // Emails need mailto: prepended
        SVLinkType type = [oLinkTypePopUpButton selectedTag];
        if (type == SVLinkEmail || [KSURLFormatter isValidEmailAddress:urlString])
        {
            urlString = [[NSURL ks_mailtoURLWithEmailAddress:urlString] absoluteString];
        }
        
        // Apply to model
        SVLink *link = [[SVLink alloc] initWithURLString:urlString
                                         openInNewWindow:[oExternalLinkOpenInNewWindowCheckbox intValue]];
        [[SVLinkManager sharedLinkManager] modifyLinkTo:link];
        [link release];
    }
}

- (IBAction)openInNewWindow:(NSButton *)sender;
{
    // Apply to model. If user clicked the "open in new window" box first, without entering URL, ignore
    SVLink *link = [[[SVLinkManager sharedLinkManager] selectedLink]
                    linkWithOpensInNewWindow:[sender intValue]];
    
    if (link) [[SVLinkManager sharedLinkManager] modifyLinkTo:link];
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
