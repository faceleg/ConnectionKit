//
//  RSSBadgeInspector.m
//  RSSBadgeElement
//
//  Created by Dan Wood on 2/24/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "RSSBadgeInspector.h"
#import "RSSBadgePlugin.h"


@implementation RSSBadgeInspector

- (NSString *)nibName { return @"RSSBadge"; }


#pragma mark -
#pragma mark Init

+ (void)initialize
{
	// Register value trasnsformers
	KSIsEqualValueTransformer *transformer = nil;
	
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:[NSNumber numberWithInt:RSSBadgeIconStyleStandardOrangeLarge]];
	[transformer setNegatesResult:YES];
	[NSValueTransformer setValueTransformer:transformer forName:@"RSSBadgeIconIsNotStandardOrangeLarge"];
	[transformer release];
	
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:[NSNumber numberWithInt:RSSBadgeIconStyleStandardGrayLarge]];
	[transformer setNegatesResult:YES];
	[NSValueTransformer setValueTransformer:transformer forName:@"RSSBadgeIconIsNotStandardGrayLarge"];
	[transformer release];
}

- (void)awakeFromNib
{
	// Connect up the target icon if needed
	NSArray *selectedObjects = [[self inspectedObjectsController] selectedObjects];
	KTPage *collection = (KTPage *)[NSNull null];		// placeholder for not known
	NSCellStateValue state = NSMixedState;
	for (RSSBadgePlugin *plugin in selectedObjects)
	{
		if (collection == (KTPage *)[NSNull null])
		{
			collection = plugin.collection;	// first pass through
			state = (nil != collection) ? NSOnState : NSOffState;
		}
		else
		{
			if (collection != plugin.collection)
			{
				state = NSMixedState;
				break;		// no point in continuing; it's a mixed state and there's no going back
			}
		}
	}
	[collectionLinkSourceView setConnected:(state == NSOnState)];
}






#pragma mark -
#pragma mark Link source dragging

- (id)userInfoForLinkSource:(KTLinkSourceView *)link
{
	return [[self page] site];
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
	
	KTPage *target = [KTPage pageWithUniqueID:collectionID inManagedObjectContext:[[[self inspectedObjectsController] selection] managedObjectContext]];
	if (target)
	{
		[[[self inspectedObjectsController] selection] setValue:target forKey:@"collection"];
		[collectionLinkSourceView setConnected:YES];
	}
}

- (IBAction)clearCollectionLink:(id)sender
{
	[[[self inspectedObjectsController] selection] setValue:nil forKey:@"collection"];
	[collectionLinkSourceView setConnected:NO];
}





@end
