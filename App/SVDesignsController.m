//
//  SVDesignsController.m
//  Sandvox
//
//  Created by Dan Wood on 5/7/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVDesignsController.h"
#import "KTDesign.h"

@implementation SVDesignsController

@synthesize rangesOfGroups = _rangesOfGroups;

- (void) dealloc
{
	self.rangesOfGroups = nil;
	[super dealloc];
}

- (NSArray *)arrangeObjects:(NSArray *)objects;
{
    objects = [super arrangeObjects:objects];		// do the filtering
	NSArray *newRangesOfGroups;
	objects = [KTDesign reorganizeDesigns:objects familyRanges:&newRangesOfGroups];
	self.rangesOfGroups = newRangesOfGroups;
	return objects;
}

- (BOOL)setSelectionIndex:(NSUInteger)index;
{
	return [super setSelectionIndex:index];
}
- (BOOL)setSelectionIndexes:(NSIndexSet *)indexes;    // to deselect all: empty index set, to select all: index set with indexes [0...count - 1]
{
	return [super setSelectionIndexes:indexes];
}

@end

