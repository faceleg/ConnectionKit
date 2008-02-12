//
//  NSSet+KTExtensions.m
//  KTComponents
//
//  Created by Dan Wood on 9/2/05.
//  Copyright (c) 2005 Biophony LLC. All rights reserved.
//

#import "NSSet+KTExtensions.h"

#import "KTAbstractPlugin.h"
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

- (NSArray *)orderedObjects
{
#warning We need to come up with a replacement for this; gOrderingDescriptor was removed in 1.5
//	return [[self allObjects] sortedArrayUsingDescriptors:gOrderingDescriptor];
	return [self allObjects];	// FOR NOW
}

- (NSString *)shortDescription
{
	NSString *result = @"";
	
	NSEnumerator *e = [[self orderedObjects] objectEnumerator];
	id object;
	while ( object = [e nextObject] )
	{
		result = [result stringByAppendingFormat:@"\t%@:%@,\n", [object wrappedValueForKeyWithFallback:@"ordering"], [object shortDescription]];
	}
	
	result = [result stringByAppendingFormat:@"\n"];
	
	return result;
}

@end
