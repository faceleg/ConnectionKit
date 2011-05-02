//
//  KTDesignFamily.m
//  Sandvox
//
//  Created by Dan Wood on 11/19/09.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
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
			if ([self.designs count])
			{
				result = self.familyPrototype = [self.designs pointerAtIndex:0];
			}
		}
		
	}
	return result;
}

- (id) init
{
	self = [super init];
	if ( self != nil )
	{
		_designs = [[NSPointerArray alloc] initWithOptions:
					NSPointerFunctionsZeroingWeakMemory|
					NSPointerFunctionsObjectPointerPersonality];
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
	if ([aDesign isFamilyPrototype] && [self.designs count])
	{
		// insert at beginning of array
		[self.designs insertPointer:aDesign atIndex:0];	// family prototype goes first
		OBASSERT([self.designs count] == [self.designs.allObjects count]);
	}
	else
	{
		[self.designs addPointer:aDesign];
		OBASSERT([self.designs count] == [self.designs.allObjects count]);
	}
}


@end
