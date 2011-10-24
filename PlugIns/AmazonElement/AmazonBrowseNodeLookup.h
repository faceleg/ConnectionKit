//
//  AmazonBrowseNodeLookup.h
//  iMediaAmazon
//
//  Created by Dan Wood on 1/2/07.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AmazonECSOperation.h"

@interface AmazonBrowseNodeLookup : AmazonECSOperation {

	NSString *myBrowseNodeID;
	id myTreeInfo;
}

- (id)initWithBrowseNodeID:(NSString *)aBrowseNodeID
				  treeInfo:(id)treeInfo;

- (id)treeInfo;

- (NSArray *)topSellers;
- (NSArray *)newReleases;
- (NSArray *)children;

@end
