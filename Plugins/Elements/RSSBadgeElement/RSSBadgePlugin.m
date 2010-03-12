//
//  RSSBadgePlugin.m
//  RSSBadgeElement
//
//  Created by Dan Wood on 2/24/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "RSSBadgePlugin.h"
#import "RSSBadgeInspector.h"


@implementation RSSBadgePlugin

@synthesize iconStyle = _iconStyle;
@synthesize label = _label;
@synthesize collection = _collection;

+ (Class)inspectorViewControllerClass { return [RSSBadgeInspector class]; }
+ (NSSet *)plugInKeys
{
	return [NSSet setWithObjects:@"iconStyle", @"collection", @"label", nil];
}

- (void)dealloc
{
	self.label = nil;
	self.collection = nil;
	[super dealloc];
}

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewObject
{
	if (isNewObject)
	{
		// Use an appropriately localized label
		//
		// Make the string we want get generated, but we are forcing the string to be in target language.
		//
		NSBundle *theBundle = [NSBundle bundleForClass:[self class]];
		NSString *language = [[SVHTMLContext currentContext] language];   OBASSERT(language);
        
        NSString *theString = [theBundle localizedStringForString:@"Subscribe to RSS feed" 
														 language:language
														 fallback:LocalizedStringInThisBundle(@"Subscribe to RSS feed", 
																							  @"Prompt to subscribe to the given collection via RSS")];
		
		self.label = theString;
		
		// Try and connect to our parent collection
		KTPage *parent = (KTPage *)[self page];
		if ([parent feedURL])
		{
			self.collection = parent;
		}
	}
}

#pragma mark -
#pragma mark HTML Generation

+ (NSSet *)keyPathsForValuesAffectingUseLargeIconLayout
{
	return [NSSet setWithObject:@"iconStyle"];
}

- (BOOL)useLargeIconLayout
{
	// Use the large icon layout if the large orange or grey feed icon has been chosen
	RSSBadgeIconStyle iconStyle = self.iconStyle;
	BOOL result = (iconStyle == RSSBadgeIconStyleStandardOrangeLarge || iconStyle == RSSBadgeIconStyleStandardGrayLarge);
	return result;
}


#pragma mark -
#pragma mark Resources

+ (NSSet *)keyPathsForValuesAffectingFeedIconResourcePath
{
	return [NSSet setWithObject:@"iconStyle"];
}

- (NSString *)feedIconResourcePath
{
	// The path to the RSS feed icon
	NSString *iconName = nil;
	
	switch (self.iconStyle)
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
		default:
		case RSSBadgeIconStyleNone:
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
