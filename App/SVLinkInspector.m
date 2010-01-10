//
//  SVLinkInspector.m
//  Sandvox
//
//  Created by Mike on 10/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVLinkInspector.h"

#import "KTDocument.h"


@implementation SVLinkInspector

@synthesize inspectedWindow = _inspectedWindow;

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
	
    
    /*
    NSDictionary *info = [self contextElementInformation];
	if (info)
	{
		// set up a link to the local page
		NSString *pageID = [pboard stringForType:kKTLocalLinkPboardType];
		if ( (pageID != nil) && ![pageID isEqualToString:@""] )
		{
			KTPage *target = [KTPage pageWithUniqueID:pageID inManagedObjectContext:[[self document] managedObjectContext]];
			if ( nil != target )
			{
				NSString *titleText = [[target title] text];
				if ( (nil != titleText) && ![titleText isEqualToString:@""] )
				{
					[oLinkLocalPageField setStringValue:titleText];
					[oLinkDestinationField setStringValue:@""];
					[oLinkLocalPageField setHidden:NO];
					[oLinkDestinationField setHidden:YES];
					
					[info setValue:[NSString stringWithFormat:@"%@%@", kKTPageIDDesignator, pageID] forKey:@"KTLocalLink"];
					[oLinkView setConnected:YES];
					
				}
			}
		}
	}
	//	NO, DON'T CLOSE THE LINK PANEL WHEN YOU DRAG.	[oLinkPanel orderOut:self];
     
     */
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
