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
    [self setInspectedLink:[[SVLinkManager sharedLinkManager] selectedLink]];
}

#pragma mark Link

- (void)setInspectedLink:(SVLink *)link;
{
    // Make the link field editable if there is nothing entered, or the URL is typed in
    if ([link page])
    {
        // Configure for a local link
        [oLinkField setEditable:NO];
        [oLinkField setBackgroundColor:[NSColor controlHighlightColor]];
        [oLinkField setFormatter:nil];
        
        [oLinkSourceView setConnected:YES];
        
        NSString *title = [[[link page] title] text];
        if (!title) title = @"";
        [oLinkField setStringValue:title];
    }
    else
    {
        // Configure for a generic link
        if (!_URLFormatter) _URLFormatter = [[KSURLFormatter alloc] init];
        [oLinkField setFormatter:_URLFormatter];
        [oLinkField setBackgroundColor:[NSColor textBackgroundColor]];
        
        [oLinkSourceView setConnected:NO];
        
        NSString *title = [link URLString];
        if (!title) title = @"";
        [oLinkField setStringValue:title];
    }
    
    [oOpenInNewWindowCheckbox setState:([link openInNewWindow] ? NSOnState : NSOffState)];
}

- (SVLinkManager *)linkManager
{
    // Exposed only here for the benefit of bindings
    return [SVLinkManager sharedLinkManager];
}

#pragma mark UI Actions

- (id)userInfoForLinkSource:(KTLinkSourceView *)link
{
	return [[[[NSApp mainWindow] windowController] document] site];
}

- (NSPasteboard *)linkSourceDidBeginDrag:(KTLinkSourceView *)link
{
	NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
	[pboard declareTypes:[NSArray arrayWithObject:kKTLocalLinkPboardType] owner:self];
	[pboard setString:@"LocalLink" forType:kKTLocalLinkPboardType];
	
	return pboard;
}

- (void)linkSourceDidEndDrag:(KTLinkSourceView *)link withPasteboard:(NSPasteboard *)pboard
{
	// set up a link to the local page
    NSString *pageID = [pboard stringForType:kKTLocalLinkPboardType];
    if (pageID)
    {
        KTPage *target = [KTPage pageWithUniqueID:pageID inManagedObjectContext:[[[[NSApp mainWindow] windowController] document] managedObjectContext]];
        if (target)
        {
            SVLink *link = [[SVLink alloc] initWithPage:target];
            [[SVLinkManager sharedLinkManager] modifyLinkTo:link];
            [link release];
        }
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
