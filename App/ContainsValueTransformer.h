//
//  ContainsValueTransformer.h
//  Amazon List
//
//  Created by Mike on 05/06/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ContainsValueTransformer : NSValueTransformer
{
	NSSet	*myValues;
	BOOL	myNegateResult;
}

- (id)initWithComparisonObjects:(NSSet *)values;

- (BOOL)negatesResult;
- (void)setNegatesResult:(BOOL)negateResult;

@end
