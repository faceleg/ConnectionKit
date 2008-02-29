//
//  RSSBadgeDelegate.m
//  RSS Badge
//
//  Created by Mike on 20/11/2006.
//  Copyright 2006 Karelia. All rights reserved.
//

#import "CollectionArchiveDelegate.h"


@implementation CollectionArchiveDelegate

#pragma mark -
#pragma mark Init

- (void)awakeFromNib
{
	// Connect up the target icon if needed
	[collectionLinkSourceView setConnected:([[self delegateOwner] valueForKey:@"collection"] != nil)];
}

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewObject
{
	if (isNewObject)
	{
		// Try and connect to our parent collection
		KTPage *parent = (KTPage *)[self page];
		if ([parent isCollection])
		{
			[[self delegateOwner] setValue:parent forKey:@"collection"];
		}
	}
	
	[[[self delegateOwner] valueForKey:@"collection"] setCollectionGenerateArchives:YES];
}

#pragma mark -
#pragma mark Link source dragging

- (id)userInfoForLinkSource:(KTLinkSourceView *)link
{
	return [self document];
}

- (NSPasteboard *)linkSourceDidBeginDrag:(KTLinkSourceView *)link
{
	// We only accept Collections
	NSPasteboard *dragPasteboard = [NSPasteboard pasteboardWithName:NSDragPboard];
	
	[dragPasteboard declareTypes:[NSArray arrayWithObject:@"kKTLocalLinkPboardType"]
						   owner:self];
	
	[dragPasteboard setString:@"KTCollection" forType:@"kKTLocalLinkPboardType"];
	
	return dragPasteboard;
}

- (void)linkSourceDidEndDrag:(KTLinkSourceView *)link withPasteboard:(NSPasteboard *)pboard
{
	// Bail if nothing was selected
	NSString *collectionID = [pboard stringForType:@"kKTLocalLinkPboardType"];
	if (!collectionID || [collectionID isEqualToString:@""])
		return;
	
	KTPage *target = [[self managedObjectContext] pageWithUniqueID:collectionID];
	if (target)
	{
		[[self delegateOwner] setValue:target forKey:@"collection"];
	}
}

- (IBAction)clearCollectionLink:(id)sender
{
	[[self delegateOwner] setValue:nil forKey:@"collection"];
	[collectionLinkSourceView setConnected:NO];
}

#pragma mark -
#pragma mark Settings

/*	Changing collection means disabling archives on the old collection if necessary
 */
- (void)plugin:(KTAbstractElement *)plugin didSetValue:(id)value forPluginKey:(NSString *)key oldValue:(id)oldValue
{
	if ([key isEqualToString:@"collection"])
	{
		// Turn off the old collection's archives if not needed
		BOOL enableArchives = NO;
		NSArray *archivePagelets = [[plugin managedObjectContext] pageletsWithPluginIdentifier:[[self bundle] bundleIdentifier]];
		NSEnumerator *pageletsEnumerator = [archivePagelets objectEnumerator];
		KTPagelet *aPagelet;
		while (aPagelet = [pageletsEnumerator nextObject])
		{
			if ([[aPagelet valueForKey:@"collection"] isEqual:(KTPage *)oldValue])
			{
				enableArchives = YES;
				break;
			}
		}
		[(KTPage *)oldValue setCollectionGenerateArchives:enableArchives];
		
		// Enable archives on the new page.
		[(KTPage *)value setCollectionGenerateArchives:YES];
	}
}

@end
