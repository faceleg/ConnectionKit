//
//  KTDesignFamily.m
//  Sandvox
//
//  Created by Dan Wood on 11/19/09.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KTDesignFamily.h"
#import "KTDesign.h"

@implementation KTDesignFamily

@synthesize designs = designs_;

- (id) init
{
	self = [super init];
	if ( self != nil )
	{
		designs_ = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void) dealloc
{
	self.designs = nil;
	[super dealloc];
}

- (void) addDesign:(KTDesign *)aDesign;
{
	[self.designs addObject:aDesign];
}
@end
