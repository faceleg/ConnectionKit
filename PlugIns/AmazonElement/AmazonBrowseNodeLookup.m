//
//  AmazonBrowseNodeLookup.m
//  iMediaAmazon
//
//  Created by Dan Wood on 1/2/07.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import "AmazonBrowseNodeLookup.h"

#import "AmazonItemLookup.h"
#import "AmazonItem.h"
#import "AmazonMiniItem.h"

#import "NSString+Amazon.h"

@interface AmazonBrowseNodeLookup (Private)

- (NSString *)browseNodeID;
- (void)setBrowseNodeID:(NSString *)aBrowseNodeID;
- (void)setTreeInfo:(id)anTreeInfo;

@end

@implementation AmazonBrowseNodeLookup

+ (NSArray *)defaultResponseGroups
{
	return [NSArray arrayWithObjects:@"BrowseNodeInfo", @"TopSellers", @"NewReleases", nil];
}

- (id)initWithBrowseNodeID:(NSString *)aBrowseNodeID
				  treeInfo:(id)treeInfo;
{
	NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:
		aBrowseNodeID, @"BrowseNodeId",
		nil];

	[self initWithStore: AmazonStoreUS			// Browse Nodes lookup is ALWAYS **** USA ****
			  operation: @"BrowseNodeLookup"
			 parameters: parameters
		  resultListKey:@"BrowseNodeLookupResponse"
			  resultKey:@"BrowseNodes"];
	[self setBrowseNodeID: aBrowseNodeID];
	[self setTreeInfo:treeInfo];

	return self;
}

- (void)dealloc
{
	[self setBrowseNodeID:nil];
	[super dealloc];
}


#pragma mark -
#pragma mark Data Fetchers

// BrowseNode -> BrowseNodeId, BrowseNode -> Name

// TODO: USE WRAPPER PATTERN POSSIBLY
- (NSArray *)children
{
	// Use cached value if available
	if ([self valueForKeyIsCached: @"children"])
	{
		return [self cachedValueForKey: @"children"];
	}

	// I need some way to also indicate the Amazon Store in this.  Should I set up a userInfo dictionary of additional context to pass in, and propagate that?
	
	NSArray *result = [self fetchArrayOfObjectAtXPath:@"/BrowseNodeLookupResponse/BrowseNodes/BrowseNode/Children/BrowseNode"
											  asClass:[NSDictionary class]];
	[self cacheValue:result forKey: @"children"];
	return result;
}

// For Each: TopSeller -> ASIN, TopSeler -> Title

- (NSArray *)topSellers
{
	// Use cached value if available
	if ([self valueForKeyIsCached: @"topSellers"])
	{
		return [self cachedValueForKey: @"topSellers"];
	}

	NSArray *result = [self fetchArrayOfObjectAtXPath:@"/BrowseNodeLookupResponse/BrowseNodes/BrowseNode/TopSellers/TopSeller"
											  asClass:[AmazonMiniItem class]];
	[self cacheValue:result forKey: @"topSellers"];
	return result;
}


- (NSArray *)newReleases
{
	// Use cached value if available
	if ([self valueForKeyIsCached: @"newReleases"])
	{
		return [[[self cachedValueForKey: @"newReleases"] retain] autorelease];	// Clang was complaining: Method returns an Objective-C object with a +0 retain count (non-owning reference)
	}
	
	NSArray *result = [self fetchArrayOfObjectAtXPath:@"/BrowseNodeLookupResponse/BrowseNodes/BrowseNode/NewReleases/NewRelease"
											  asClass:[AmazonMiniItem class]];
	[self cacheValue:result forKey: @"newReleases"];
	return result;
}

#pragma mark -
#pragma mark Accessors

- (NSString *)browseNodeID
{
    return myBrowseNodeID;
}

- (void)setBrowseNodeID:(NSString *)aBrowseNodeID
{
    [aBrowseNodeID retain];
    [myBrowseNodeID release];
    myBrowseNodeID = aBrowseNodeID;
}

- (id)treeInfo
{
    return myTreeInfo;
}

- (void)setTreeInfo:(id)anTreeInfo
{
    [anTreeInfo retain];
    [myTreeInfo release];
    myTreeInfo = anTreeInfo;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ ID:%@ TreeInfo:%@", [super description], myBrowseNodeID, [myTreeInfo description]];
}

@end