//
//  SVExtensibleManagedObject.m
//  KTComponents
//
//  Created by Terrence Talbot on 6/22/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "SVExtensibleManagedObject.h"


@implementation SVExtensibleManagedObject

// Disable support for extensible properties
- (BOOL)canStoreExtensiblePropertyForKey:(NSString *)key { return NO; }

@end
