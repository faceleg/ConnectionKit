//
//  SVHTMLContext+CurrentContext.m
//  Sandvox
//
//  Created by Mike on 14/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//


#import "SVHTMLContext.h"


@implementation SVHTMLContext (CurrentContext)

#pragma mark Stack

+ (SVHTMLContext *)currentContext
{
    SVHTMLContext *result = [[[[NSThread currentThread] threadDictionary] objectForKey:@"SVHTMLGenerationContextStack"] lastObject];
    return result;
}

+ (void)pushContext:(SVHTMLContext *)context
{
    OBPRECONDITION(context);
    
    NSMutableArray *stack = [[[NSThread currentThread] threadDictionary] objectForKey:@"SVHTMLGenerationContextStack"];
    if (!stack) stack = [NSMutableArray arrayWithCapacity:1];
    [stack addObject:context];
    [[[NSThread currentThread] threadDictionary] setObject:stack forKey:@"SVHTMLGenerationContextStack"];
}

+ (void)popContext
{
    NSMutableArray *stack = [[[NSThread currentThread] threadDictionary] objectForKey:@"SVHTMLGenerationContextStack"];
    
    // Be kind and warn if it looks like the stack shouldn't be popped yet
    SVHTMLContext *context = [stack lastObject];
    if ([context performSelector:@selector(currentIterator)])
    {
        NSLog(@"Popping HTML context while it is still iterating. Either you popped the context too soon, or forgot to call -[SVHTMLContext nextIteration] enough times");
    }
    
    // Do the pop
    [stack removeLastObject];
}

- (void)push { [SVHTMLContext pushContext:self]; }

- (void)pop;
{
    if ([SVHTMLContext currentContext] == self) [SVHTMLContext popContext];
}

@end
