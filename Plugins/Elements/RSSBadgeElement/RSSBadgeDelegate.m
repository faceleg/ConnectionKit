//
//  RSSBadgeDelegate.m
//  RSS Badge
//
//  Created by Mike on 20/11/2006.
//  Copyright 2006 Karelia. All rights reserved.
//

#import "RSSBadgeDelegate.h"


@implementation RSSBadgeDelegate

#pragma mark -
#pragma mark Init

+ (void)initialize
{
	// Register value trasnsformers
	ValuesAreEqualTransformer *transformer = nil;
	
	transformer = [[ValuesAreEqualTransformer alloc] initWithComparisonValue:[NSNumber numberWithInt:RSSBadgeIconStyleStandardOrangeLarge]];
	[transformer setNegatesResult:YES];
	[NSValueTransformer setValueTransformer:transformer forName:@"RSSBadgeIconIsNotStandardOrangeLarge"];
	[transformer release];
	
	transformer = [[ValuesAreEqualTransformer alloc] initWithComparisonValue:[NSNumber numberWithInt:RSSBadgeIconStyleStandardGrayLarge]];
	[transformer setNegatesResult:YES];
	[NSValueTransformer setValueTransformer:transformer forName:@"RSSBadgeIconIsNotStandardGrayLarge"];
	[transformer release];
}

- (void)awakeFromNib
{
	// Connect up the target icon if needed
	[collectionLinkSourceView setConnected:([[self delegateOwner] valueForKey:@"collection"] != nil)];
}

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewObject
{
	if (isNewObject)
	{
		// Use an appropriately localized label
		//
		// Make the string we want get generated, but we are forcing the string to be in target language.
		//
		//
		// LocalizedStringInThisBundle(@"Subscribe to RSS feed", @"Prompt to subscribe to the given collection via RSS")
		//
		NSBundle *theBundle = [NSBundle bundleForClass:[self class]];
		NSString *theString = [theBundle localizedStringForKey:@"Subscribe to RSS feed" value:@"" table:nil];
#warning TODO: Have a way to have localized strings in initialPluginProperties!
		
		[[self delegateOwner] setObject:theString forKey:@"label"];
			
		
		// Try and connect to our parent collection
		KTPage *parent = (KTPage *)[[self delegateOwner] page];
		NSString *pageFeedURL = [parent feedURLPath];
		
		if (pageFeedURL && ![pageFeedURL isEqualToString:@""]) {
			[[self delegateOwner] setValue:parent forKey:@"collection"];
		}
	}
}

#pragma mark -
#pragma mark HTML Generation

- (BOOL)useLargeIconLayout
{
	// Use the large icon layout if the large orange or grey feed icon has been chosen
	RSSBadgeIconStyle iconStyle = [[self delegateOwner] integerForKey:@"iconStyle"];
	BOOL result = (iconStyle == RSSBadgeIconStyleStandardOrangeLarge || iconStyle == RSSBadgeIconStyleStandardGrayLarge);
	return result;
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
	
	KTPage *target = [KTPage pageWithUniqueID:collectionID inManagedObjectContext:[self managedObjectContext]];
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
#pragma mark Resources

- (NSString *)feedIconResourcePath
{
	// The path to the RSS feed icon
	NSString *iconName = nil;
	
	switch ([[self delegateOwner] integerForKey:@"iconStyle"])
	{
		case RSSBadgeIconStyleStandardOrangeSmall:
			iconName = @"orange_small.png";
			break;
		
		case RSSBadgeIconStyleStandardOrangeLarge:
			iconName = @"orange_large.png";
			break;
		
		case RSSBadgeIconStyleStandardGraySmall:
			iconName = @"gray_small.png";
			break;
		
		case RSSBadgeIconStyleStandardGrayLarge:
			iconName = @"gray_large.png";
			break;
		
		case RSSBadgeIconStyleAppleRSS:
			iconName = @"rss_blue.png";
			break;
		
		case RSSBadgeIconStyleFlatXML:
			iconName = @"xml.gif";
			break;
		
		case RSSBadgeIconStyleFlatRSS:
			iconName = @"rss.gif";
			break;
	}
	
	NSString *path = [[self bundle] pathForImageResource:iconName];
	
	return path;
}

// called via recursiveComponentPerformSelector

- (void)addResourcesToSet:(NSMutableSet *)aSet forPage:(KTPage *)aPage
{
	// Add the correct RSS feed icon to the page's resources
	NSString *path = [self feedIconResourcePath];
	if (path && ![path isEqualToString:@""]) {
		[aSet addObject:path];
	}
}


// LocalizedStringInThisBundle(@"Please use the Inspector to connect this pagelet to a suitable collection in your site.", "RSSBadge")
// LocalizedStringInThisBundle(@"To subscribe to this feed, drag or copy/paste this link to an RSS feed reader application.", @"RSS Badge")
// LocalizedStringInThisBundle(@"The chosen collection has no RSS feed.  Please use the Inspector to set it to generate an RSS feed and have an index.", @"RSS Badge")

@end
