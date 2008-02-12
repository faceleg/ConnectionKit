//
//  KTWeakReferenceMutableDictionary.m
//  Marvel
//
//  Created by Mike on 04/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTWeakReferenceMutableDictionary.h"


@implementation KTWeakReferenceMutableDictionary

- (id)init
{
	[super init];
	myDictionary = [[NSMutableDictionary alloc] init];
	return self;
}

- (void)dealloc
{
	[self removeAllObjects];
	[myDictionary release];
	
	[super dealloc];
}

- (unsigned)count
{
	return [myDictionary count];
}

- (id)objectForKey:(id)aKey
{
	return [myDictionary objectForKey:aKey];
}

- (NSEnumerator *)keyEnumerator
{
	return [myDictionary keyEnumerator];
}

/*	In these methods we must provide an opposing retain and release to NSMutableDictionary
 *	so that the object is effectively a weak reference.
 */
- (void)setObject:(id)anObject forKey:(id)aKey
{
	id existingObject = [myDictionary objectForKey:aKey];
	
	if (existingObject)
	{
		[existingObject retain];
	}
	
	[myDictionary setObject:anObject forKey:aKey];
	[anObject release];
}

- (void)removeObjectForKey:(id)aKey
{
	id existingObject = [myDictionary objectForKey:aKey];
	[existingObject retain];
	[myDictionary removeObjectForKey:aKey];
}

@end
