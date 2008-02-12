//
//  ValuesAreEqualTransformer.h
//  KTComponents
//
//  Created by Mike on 11/04/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ValuesAreEqualTransformer : NSValueTransformer
{
	id		myValue;
	BOOL	myNegateResult;
}

- (id)initWithComparisonValue:(id)value;

- (BOOL)negatesResult;
- (void)setNegatesResult:(BOOL)negateResult;
@end
