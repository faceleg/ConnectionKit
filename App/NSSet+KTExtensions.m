//
//  NSSet+KTExtensions.m
//  KTComponents
//
//  Created by Dan Wood on 9/2/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "NSSet+KTExtensions.h"

#import "NSObject+Karelia.h"
#import "NSObject+KTExtensions.h"


@implementation NSSet ( Ordering )

- (NSString *)shortDescription
{
	NSString *result = @"";
	
	NSEnumerator *e = [self objectEnumerator];
	id object;
	while ( object = [e nextObject] )
	{
		result = [result stringByAppendingFormat:@"\t%@:%@,\n", [object wrappedValueForKeyWithFallback:@"ordering"], [object shortDescription]];
	}
	
	result = [result stringByAppendingFormat:@"\n"];
	
	return result;
}

#pragma mark -
#pragma mark Deriving New Sets

- (NSSet *)setByRemovingObjects:(NSSet *)objects
{
	NSMutableSet *buffer = [self mutableCopy];
	[buffer minusSet:objects];
	
	NSSet *result = [[buffer copy] autorelease];
	[buffer release];
	return result;
}

- (NSSet *)setByIntersectingSet:(NSSet *)objects
{
	NSMutableSet *buffer = [self mutableCopy];
	[buffer intersectSet:objects];
	
	NSSet *result = [[buffer copy] autorelease];
	[buffer release];
	return result;
}

- (NSSet *)setByIntersectingObjectsFromArray:(NSArray *)array
{
	NSSet *set = [[NSSet alloc] initWithArray:array];
	NSSet *result = [self setByIntersectingSet:set];
	[set release];
	return result;
}

@end

