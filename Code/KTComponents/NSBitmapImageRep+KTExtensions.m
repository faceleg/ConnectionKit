//
//  NSBitmapImageRep+KTExtensions.m
//  KTComponents
//
//  Created by Dan Wood on 9/16/05.
//  Copyright (c) 2005 Biophony LLC. All rights reserved.
//

#import "NSBitmapImageRep+Karelia.h"

@implementation NSBitmapImageRep ( KTExtensions )

- (NSMutableDictionary *)dictionaryOfPropertiesWithSetOfKeys:(NSSet *)aKeySet
{
	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	NSEnumerator *theEnum = [aKeySet objectEnumerator];
	id propKey;
	while (nil != (propKey = [theEnum nextObject]) )
	{
		id value = [self valueForProperty:propKey];
		if (value)
		{
			[result setObject:value forKey:propKey];
		}
	}
	return result;
}


@end
