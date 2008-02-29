//
//  KTArchivePage.m
//  Marvel
//
//  Created by Mike on 29/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTArchivePage.h"

#import "assertions.h"


@implementation KTArchivePage

+ (NSString *)entityName { return @"ArchivePage"; }

/*	Stop KSExtensibleManagedObject kicking in
 */
- (id)valueForUndefinedKey:(NSString *)key
{
	OBASSERT_NOT_REACHED("");
	return [super valueForUndefinedKey:key];
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
	OBASSERT_NOT_REACHED("");
	[super setValue:value forUndefinedKey:key];
}

@end
