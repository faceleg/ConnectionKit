//
//  KTAbstractPlugin+Deprecated.m
//  Marvel
//
//  Created by Mike on 27/08/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTAbstractPlugin.h"


@implementation KTAbstractPlugin (Deprecated)

#pragma mark -
#pragma mark Plugin Properties

- (id)pluginProperties
{
	return self;
}

#pragma mark KTStoredDictionary

/*	These methods are here to provide most of the functionality that KTStoredDictionary
 *	used to offer.
 */
- (id)objectForKey:(id)aKey
{
	return [self valueForUndefinedKey:aKey];
}

- (void)setObject:(id)anObject forKey:(id)aKey
{
	[self setValue:anObject forUndefinedKey:aKey];
}

- (void)removeObjectForKey:(id)aKey
{
	[self setValue:nil forUndefinedKey:aKey];
}

@end
