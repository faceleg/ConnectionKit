//
//  NSMutableSet+KTExtensions.m
//  KTComponents
//
//  Created by Terrence Talbot on 9/14/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "NSMutableSet+KTExtensions.h"


@implementation NSMutableSet ( KTExtensions )

/*	Just like -addObject: but it won't freak out if you pass in nil
 */
- (void)addObjectIgnoringNil:(id)anObject
{
	if (anObject)
	{
		[self addObject:anObject];
	}
}

- (void)removeObjectIgnoringNil:(id)anObject;
{
	if (anObject)
	{
		[self removeObject:anObject];
	}
}

- (void)addMediaInfoObject:(NSDictionary *)aDictionary
{
	NSString *mediaDigest = [aDictionary valueForKey:@"mediaDigest"];
	NSString *thumbnailDigest = [aDictionary valueForKey:@"thumbnailDigest"];
	
	NSEnumerator *e = [[self allObjects] objectEnumerator];
	id object;
	while ( object = [e nextObject] )
	{
		if ( [mediaDigest isEqualToString:[object valueForKey:@"mediaDigest"]] )
        {
            if ( nil != thumbnailDigest )
            {
                if ( [thumbnailDigest isEqualToString:[object valueForKey:@"thumbnailDigest"]] )
                {
                    return; // we found a matching object, no need to add it again
                }
            }
            else
            {
                return; // we found a matching object, no need to add it again
            }
        }
	}
	
	// we didn't find a matching object, so add it normally
	[self addObject:aDictionary];
}

- (void)addMediaInfoObjectsFromArray:(NSArray *)anArray
{
	NSEnumerator *e = [anArray objectEnumerator];
	id mediaInfoObject;
	while ( mediaInfoObject = [e nextObject] )
	{
		[self addMediaInfoObject:mediaInfoObject];
	}
}

@end
