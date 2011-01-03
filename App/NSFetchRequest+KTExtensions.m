//
//  NSFetchRequest+KTExtensions.m
//  KTComponents
//
//  Created by Terrence Talbot on 10/6/05.
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//

#import "NSFetchRequest+KTExtensions.h"


@implementation NSFetchRequest ( KTExtensions )

- (NSString *)shortDescription
{
	// just log entity and predicate, e.g., (entity: Media; predicate: (uniqueID LIKE "120");)
	NSString *entityName = [[self entity] name];
	NSString *predicateFormat = [[self predicate] predicateFormat];
	
	if ( nil != predicateFormat )
	{
		return [NSString stringWithFormat:@"(entity: %@; predicate: %@;)", entityName, predicateFormat];
	}
	else
	{
		return [NSString stringWithFormat:@"(entity: %@;)", entityName];
	}
}

@end
