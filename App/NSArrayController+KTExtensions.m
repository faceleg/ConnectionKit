//
//  NSArrayController+KTExtensions.m
//  KTComponents
//
//  Created by Mike on 02/01/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import "NSArrayController+KTExtensions.h"


@implementation NSArrayController (KTExtensions)

- (void)replaceObjectAtArrangedObjectIndex:(unsigned int)anIndex
								withObject:(id)object;
{
	[self removeObjectAtArrangedObjectIndex: anIndex];
	[self insertObject: object atArrangedObjectIndex: anIndex];
}

@end
