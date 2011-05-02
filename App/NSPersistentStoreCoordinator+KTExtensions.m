//
//  NSPersistentStoreCoordinator+KTExtensions.m
//  KTComponents
//
//  Created by Terrence Talbot on 4/21/05.
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//

#import "NSPersistentStoreCoordinator+KTExtensions.h"


@implementation NSPersistentStoreCoordinator ( KTExtensions )

- (BOOL)hasPersistentStores;
{
	return ((nil != [self persistentStores])
			&& ([[self persistentStores] count] > 0));
}

@end
