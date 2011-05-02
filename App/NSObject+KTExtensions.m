//
//  NSObject+KTExtensions.m
//  KTComponents
//
//  Created by Terrence Talbot on 3/16/05.
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//

#import "NSObject+KTExtensions.h"

#import "KT.h"
#import "NSManagedObject+KTExtensions.h"


@implementation NSObject ( KTExtensions )



// managed by a context?
- (BOOL)isManagedObject
{
    if ( [self isKindOfClass:[NSManagedObject class]] )
    {
        return YES;
    }
    
    // otherwise
    return NO;
}

- (id)wrappedValueForKeyWithFallback:(NSString *)aKey
{
	id value = nil;
	
	if ( [self respondsToSelector:@selector(wrappedValueForKey:)] )
	{
		value = [(NSManagedObject *)self wrappedValueForKey:aKey];
	}
	else
	{
		value = [self valueForKey:aKey];
	}
	
	return value;
}

- (void)setWrappedValueWithFallback:(id)aValue forKey:(NSString *)aKey
{
	if  ( [self respondsToSelector:@selector(wrappedValueForKey:)] )
	{
		[(NSManagedObject *)self setWrappedValue:aValue forKey:aKey];
	}
	else
	{
		[self setValue:aValue forKey:aKey];
	}
}


@end
