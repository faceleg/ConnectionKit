//
//  ContainsValueTransformer.m
//  Amazon List
//
//  Created by Mike on 05/06/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "ContainsValueTransformer.h"


@implementation ContainsValueTransformer

+ (BOOL)allowsReverseTransformation { return NO; }

+ (Class)transformedValueClass { return [NSNumber class]; }

- (id)initWithComparisonObjects:(NSSet *)values;
{
	[super init];
	
	myValues = [values copy];
	myNegateResult = NO;
	
	return self;
}

- (void)dealloc
{
	[myValues release];
	
	[super dealloc];
}

- (BOOL)negatesResult { return myNegateResult; }

- (void)setNegatesResult:(BOOL)negateResult { myNegateResult = negateResult; }

- (id)transformedValue:(id)value
{
	BOOL result = NO;
	
	if (value) {
		result = [myValues containsObject:value];
	}
	
	// Negate the result if requested
	if ([self negatesResult]) {
		result = !result;
	}
	
	return [NSNumber numberWithBool:result];
}

@end
