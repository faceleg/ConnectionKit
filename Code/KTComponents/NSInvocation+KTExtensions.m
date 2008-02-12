//
//  NSInvocation+KTExtensions.m
//  KTComponents
//
//  Created by Dan Wood on 9/25/05.
//  Copyright (c) 2005 Biophony LLC. All rights reserved.
//

#import "NSInvocation+Karelia.h"

/*
 PURPOSE OF THIS CLASS/CATEGORY:
	Simplified method to create an NSInvocation.
 
 TAXONOMY AND RELATIONSHIP TO OTHER CLASSES:
	x
 
 IMPLEMENTATION NOTES & CAUTIONS:
	x
 
 TO DO:
	x
 
 */

@implementation NSInvocation ( KTExtensions )

+ (NSInvocation *)invocationWithSelector:(SEL)aSelector target:(id)aTarget arguments:(NSArray *)anArgumentArray
{
    NSMethodSignature *methodSignature = [aTarget methodSignatureForSelector:aSelector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
    if ( nil != invocation )
    {
        [invocation setSelector:aSelector];
		if (nil != aTarget)
		{
			[invocation setTarget:aTarget];
		}
        if ( (nil != anArgumentArray) && ([anArgumentArray count] > 0) )
        {
            NSEnumerator *e = [anArgumentArray objectEnumerator];
            id argument;
            int argumentIndex = 2; // arguments start at index 2 per NSInvocation.h
            while ( argument = [e nextObject] )
            {
                if ( [argument isMemberOfClass:[NSNull class]] )
                {
                    [invocation setArgument:nil atIndex:argumentIndex];
                }
                else
                {
                    [invocation setArgument:&argument atIndex:argumentIndex];
                }
                argumentIndex++;
            }
            [invocation retainArguments];
        }
    }
	
    return invocation;
}

@end
