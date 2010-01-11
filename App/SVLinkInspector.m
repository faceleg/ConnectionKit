//
//  SVLinkInspector.m
//  Sandvox
//
//  Created by Mike on 10/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVLinkInspector.h"

#import "KTDocument.h"
#import "KTDocWindowController.h"
#import "KTPage.h"

#import "DOMRange+Karelia.h"


@implementation SVLinkInspector

#pragma mark Inspection

@synthesize inspectedWindow = _inspectedWindow;

- (DOMHTMLAnchorElement *)inspectedLink
{
    DOMHTMLAnchorElement *result = nil;
    
    NSArray *selection = [self inspectedObjects];
    if ([selection count] == 1) result = [selection objectAtIndex:0];
    
    return result;
}

- (NSObjectController *)inspectedTextControllerController;
{
    if (!_inspectedTextControllerController)
    {
        _inspectedTextControllerController = [[NSObjectController alloc] init];
    }
    
    return _inspectedTextControllerController;
}
#pragma mark Link View

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
                
                NSString *href = [NSString stringWithFormat:@"%@%@", kKTPageIDDesignator, pageID];
                if ([self inspectedLink])
                {
                    [[self inspectedLink] setHref:href];
                }
                else
                {
                }
                
                
                [link setConnected:YES];
                
            }
        }
    }
}

- (IBAction)clearLinkDestination:(id)sender;
{
	//[oLinkLocalPageField setStringValue:@""];
	//[oLinkDestinationField setStringValue:@""];
	//[oLinkLocalPageField setHidden:YES];
	//[oLinkDestinationField setHidden:NO];
	//[oLinkView setConnected:NO];
    
    [[[self inspectedWindow] firstResponder] doCommandBySelector:@selector(clearLinkDestination:)];
}


@end
