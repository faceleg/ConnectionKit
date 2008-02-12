//
//  ValuesAreEqualTransformer.m
//  KTComponents
//
//  Created by Mike on 11/04/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "ValuesAreEqualTransformer.h"


@implementation ValuesAreEqualTransformer

+ (BOOL)allowsReverseTransformation { return NO; }

+ (Class)transformedValueClass { return [NSNumber class]; }

- (id)initWithComparisonValue:(id)value
{
	[super init];
	
	myValue = [value copy];
	myNegateResult = NO;
	
	return self;
}

- (BOOL)negatesResult { return myNegateResult; }

- (void)setNegatesResult:(BOOL)negateResult { myNegateResult = negateResult; }

- (id)transformedValue:(id)value
{
	BOOL result = NO;
	
	if (value) {
		result = [value isEqual:myValue];
	}
	
	// Negate the result if requested
	if ([self negatesResult]) {
		result = !result;
	}
	
	return [NSNumber numberWithBool:result];
}

@end
