//
//  iMBAmazonBrowseNodesParser.m
//  iMediaAmazon
//
//  Created by Dan Wood on 4/5/07.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import "iMBAmazonBrowseNodesParser.h"
#import <AmazonSupport/AmazonSupport.h>


@implementation iMBAmazonBrowseNodesParser

+ (void)load	// to register
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[iMediaBrowser registerParser:[self class] forMediaType:@"amazon"];
	[pool release];
}

- (void)dealloc
{
	[myCachedLibrary release];
	[myPlaceholderChild release];
	
	[super dealloc];
}


- (id)library:(BOOL)reuseCachedData;		// overridden return value to return array of nodes
{
	if (!myCachedLibrary || !reuseCachedData)
	{
		myPlaceholderChild = [[iMBLibraryNode alloc] init];
		[myPlaceholderChild setName:LocalizedStringInThisBundle(@"(Not yet loaded)", @"placeholder name while loading")];
		
		myCachedLibrary = [[iMBLibraryNode alloc] init];
		[myCachedLibrary setName:LocalizedStringInThisBundle(@"Amazon", @"Amazon name")];
		[myCachedLibrary setParser:self];
		
		NSArray *topLevelNodes = [NSArray arrayWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"topLevelNodes" ofType:@"plist"]];
		
		NSEnumerator *enumerator = [topLevelNodes objectEnumerator];
		NSDictionary *nameAndID;
		
		while ((nameAndID = [enumerator nextObject]) != nil)
		{
			iMBLibraryNode *topLevel = [[iMBLibraryNode alloc] init];
			[topLevel setName:[nameAndID objectForKey:@"name"]];
			[topLevel setAttribute:[nameAndID objectForKey:@"id"] forKey:@"BrowseNodeID"];
			[topLevel setIconName:@"folder"];
			[topLevel addItem:[[myPlaceholderChild copy] autorelease]];
			[topLevel setParser:self];
			[myCachedLibrary addItem:topLevel];
		}
	}
	return [myCachedLibrary items];		// actually return an array of items to return >1 top level node
}

// Node selected.  Load information if not already loaded.
- (void)iMediaBrowser:(iMediaBrowser *)browser didSelectNode:(iMBLibraryNode *)node
{
	NSString *browseNodeID = [node attributeForKey:@"BrowseNodeID"];
	BOOL alreadyLoaded = [[node attributeForKey:@"loaded"] boolValue];
	if (nil != browseNodeID && !alreadyLoaded)
	{ 
		NSDictionary *treeInfo = [NSDictionary dictionaryWithObjectsAndKeys:
			node, @"node",
			nil];
		AmazonBrowseNodeLookup *request = [[[AmazonBrowseNodeLookup alloc]
			initWithBrowseNodeID:browseNodeID
						treeInfo:treeInfo] autorelease];
		[request setStore:AmazonStoreUS];		// browse node lookups are US-store ONLY!

		[request loadWithDelegate:self];
	}
}

// Node selected.  Load information if not already loaded.  When loaded, tree will be updated.
- (void)iMediaBrowser:(iMediaBrowser *)browser willExpandOutline:(NSOutlineView *)outline row:(id)row node:(iMBLibraryNode *)node
{
	NSString *browseNodeID = [node attributeForKey:@"BrowseNodeID"];
	BOOL alreadyLoaded = [[node attributeForKey:@"loaded"] boolValue];
	if (nil != browseNodeID && !alreadyLoaded)
	{
		NSDictionary *treeInfo = [NSDictionary dictionaryWithObjectsAndKeys:
			outline, @"outline",
			row, @"row",
			node, @"node",
			nil];
		AmazonBrowseNodeLookup *request = [[[AmazonBrowseNodeLookup alloc]
			initWithBrowseNodeID:browseNodeID
						treeInfo:treeInfo] autorelease];
		[request setStore:AmazonStoreUS];		// browse node lookups are US-store ONLY!
		[request loadWithDelegate:self];
	}
}

- (void)setBrowser:(id <iMediaBrowser>)browser
{
	// Does the parser need to know about iMBAmazonController?
}

// -----------------------------------------------------------------------------
// Loading Data
// -----------------------------------------------------------------------------


- (void)asyncObject:(id)request
   didFailWithError:(NSError *)error;
{
	NSDictionary *treeInfo = [request treeInfo];
	NSOutlineView *outline = [treeInfo objectForKey:@"outline"];
	id row = [treeInfo objectForKey:@"row"];
	iMBLibraryNode *node = [treeInfo objectForKey:@"node"];
	// inform the user that the download could not be made
	if (0 == [[node items] count])
	{
		// add a single child item if it's not there yet
		[node addItem:[[myPlaceholderChild copy] autorelease]];
	}
	[((iMBLibraryNode *)[[node items] objectAtIndex:0]) setName:[error localizedDescription]];
	
	[outline reloadItem:row];
}

- (void)asyncObjectDidFinishLoading:(id)request;
{
	NSDictionary *treeInfo = [((AmazonBrowseNodeLookup *)request) treeInfo];
	NSOutlineView *outline = [treeInfo objectForKey:@"outline"];
	iMBLibraryNode *node = [treeInfo objectForKey:@"node"];
	// inform the user that the download could not be made
	if (0 != [[node items] count])
	{
		[node removeAllItems];
	}
	NSEnumerator *enumerator = [[request children] objectEnumerator];
	NSDictionary *childDict;
	
	while ((childDict = [enumerator nextObject]) != nil)
	{
		iMBLibraryNode *newChild = [[iMBLibraryNode alloc] init];
		[newChild setName:[childDict objectForKey:@"Name"]];
		[newChild setAttribute:[childDict objectForKey:@"BrowseNodeId"] forKey:@"BrowseNodeID"];
		[newChild setIconName:@"folder"];
		[newChild addItem:[[myPlaceholderChild copy] autorelease]];	// assume you can expand
		[newChild setParser:self];
		[node addItem:newChild];
	}
	
	// Now we have top-sellers, new releases - for each, it's ASIN and Title.
	
	[node setAttribute:[request topSellers] forKey:@"topSellers"];
	[node setAttribute:[request newReleases] forKey:@"newReleases"];
	[node setAttribute:[NSNumber numberWithBool:YES] forKey:@"loaded"];
	
	if (nil != outline)
	{
		[outline reloadData];
	}
}


@end
