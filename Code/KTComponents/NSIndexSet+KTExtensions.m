//
//  NSIndexSet+KTExtensions.m
//  KTComponents
//
//  Created by Terrence Talbot on 9/12/04.
//  Copyright 2004 __MyCompanyName__. All rights reserved.
//

#import "NSIndexSet+Karelia.h"


@implementation NSIndexSet ( KTExtensions )

+ (NSIndexSet *)indexSetWithArray:(NSArray *)anArray
{
    // expects anArray to be an array of NSStrings representing unsignedInts
    NSMutableIndexSet *mutableIndexSet = [NSMutableIndexSet indexSet];
    
    NSEnumerator *enumerator = [anArray objectEnumerator];
    id anIndex;
    while ( anIndex = [enumerator nextObject] ) {
        [mutableIndexSet addIndex:[anIndex intValue]];
    }
	
    return [[[NSIndexSet alloc] initWithIndexSet:mutableIndexSet] autorelease];
}

- (NSArray *)indexSetAsArray
{
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:[self count]];
	
    unsigned currentIndex = [self firstIndex];
    while ( currentIndex != NSNotFound ) {
        //[array addObject:[NSNumber numberWithUnsignedInt:currentIndex]];
        [array addObject:[[NSNumber numberWithUnsignedInt:currentIndex] stringValue]];
        currentIndex = [self indexGreaterThanIndex:currentIndex];
    }
	
    return [NSArray arrayWithArray:array];
}

+ (NSIndexSet *)indexSetWithString:(NSString *)aString
{
    NSMutableIndexSet *mutableIndexSet = [NSMutableIndexSet indexSet];
    
    NSEnumerator *enumerator = [[aString pathComponents] objectEnumerator];
    id anIndex;
    while ( anIndex = [enumerator nextObject] ) {
        [mutableIndexSet addIndex:[anIndex intValue]];
    }
	
    return [[[NSIndexSet alloc] initWithIndexSet:mutableIndexSet] autorelease];
}

- (NSString *)indexSetAsString
{
	NSString *string = [NSString string];
	
    unsigned currentIndex = [self firstIndex];
    while ( currentIndex != NSNotFound ) {
		string = [string stringByAppendingPathComponent:[[NSNumber numberWithUnsignedInt:currentIndex] stringValue]];
        currentIndex = [self indexGreaterThanIndex:currentIndex];
    }
	
	return string;
}

@end
