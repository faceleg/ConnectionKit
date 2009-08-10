//
//  RSSBadgeDelegate.m
//  RSS Badge
//
//  Copyright 2006-2009 Karelia Software. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  *  Redistribution of source code must retain the above copyright notice,
//     this list of conditions and the follow disclaimer.
//
//  *  Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other material provided with the distribution.
//
//  *  Neither the name of Karelia Software nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
//  Community Note: This code is distrubuted under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//

#import "RSSBadgeDelegate.h"


@implementation RSSBadgeDelegate

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
		NSBundle *theBundle = [NSBundle bundleForClass:[self class]];
		NSString *language = [[[self page] master] language];   OBASSERT(language);
        
        NSString *theString = [theBundle localizedStringForString:@"Subscribe to RSS feed" 
														 language:language
														 fallback:LocalizedStringInThisBundle(@"Subscribe to RSS feed", 
																							  @"Prompt to subscribe to the given collection via RSS")];
		
		[[self delegateOwner] setObject:theString forKey:@"label"];
			
		
		// Try and connect to our parent collection
		KTPage *parent = (KTPage *)[[self delegateOwner] page];
		if ([parent feedURL])
		{
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
	
	KTPage *target = [KTPage pageWithUniqueID:collectionID inManagedObjectContext:[[self delegateOwner] managedObjectContext]];
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
