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
        
        NSString *title = [link URLString];
        if (!title) title = @"";
        [oLinkField setStringValue:title];
    }
}

- (SVLinkManager *)linkManager
{
    // Exposed only here for the benefit of bindings
    return [SVLinkManager sharedLinkManager];
}

#pragma mark Inspection

@synthesize inspectedWindow = _inspectedWindow;

#pragma mark Link Actions

- (id)userInfoForLinkSource:(KTLinkSourceView *)link
{
	return [[[[self inspectedWindow] windowController] document] site];
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
    if ( (pageID != nil) && ![pageID isEqualToString:@""] )
    {
        KTPage *target = [KTPage pageWithUniqueID:pageID inManagedObjectContext:[[[[self inspectedWindow] windowController] document] managedObjectContext]];
        if ( nil != target )
        {
            NSString *titleText = [[target title] text];
            if ( (nil != titleText) && ![titleText isEqualToString:@""] )
            {
                //[oLinkLocalPageField setStringValue:titleText];
                //[oLinkDestinationField setStringValue:@""];
                //[oLinkLocalPageField setHidden:NO];
                //[oLinkDestinationField setHidden:YES];
                
                [link setConnected:YES];
                
            }
        }
    }
}

- (IBAction)setLinkURL:(id)sender;
{
    SVLink *link = [[SVLink alloc] initWithURLString:[oLinkField stringValue]];
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
