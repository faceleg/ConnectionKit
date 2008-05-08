//
//  NSSet+KTExtensions.m
//  KTComponents
//
//  Created by Dan Wood on 9/2/05.
//  Copyright (c) 2005 Biophony LLC. All rights reserved.
//

#import "NSSet+KTExtensions.h"

#import "KTAbstractElement.h"
#import "NSObject+Karelia.h"
#import "NSObject+KTExtensions.h"


@implementation NSSet ( Ordering )

#ifdef DEBUG
- (NSString *)o
{
	NSMutableString *string = [NSMutableString string];
	NSEnumerator *theEnum = [self objectEnumerator];
	id object;

	while (nil != (object = [theEnum nextObject]) )
	{
		[string appendFormat:@"%@: %@  ", [object wrappedValueForKeyWithFallback:@"ordering"], [object wrappedValueForKeyWithFallback:@"pluginIdentifier"]];
	}
	return string;
}
#endif

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

