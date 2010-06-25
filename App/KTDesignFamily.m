//
//  KTDesignFamily.m
//  Sandvox
//
//  Created by Dan Wood on 11/19/09.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Quartz/Quartz.h>
#import "KTDesignFamily.h"
#import "KTDesign.h"
#import "NSArray+Karelia.h"
#import "NSData+Karelia.h"

@implementation KTDesignFamily

@synthesize designs = _designs;
@synthesize familyPrototype = _familyPrototype;

- (KTDesign *)familyPrototype
{
	KTDesign *result = _familyPrototype;
	if (nil == result)
	{
		for (KTDesign *design in self.designs)
		{
			if ([design isFamilyPrototype])
			{
				result = self.familyPrototype = design;
				break;
			}
		}
		if (!result)	// none set?  Just choose the first one.
		{
			result = self.familyPrototype = [self.designs firstObjectKS];
		}
		
	}
	return result;
}

- (id) init
{
	self = [super init];
	if ( self != nil )
	{
		_designs = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void) dealloc
{
	self.designs = nil;
	self.familyPrototype = nil;
	[super dealloc];
}

- (void) addDesign:(KTDesign *)aDesign;
{
	[self.designs addObject:aDesign];
}


@end
