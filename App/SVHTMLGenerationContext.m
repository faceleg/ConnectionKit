//
//  SVHTMLGenerationContext.m
//  Sandvox
//
//  Created by Mike on 19/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVHTMLGenerationContext.h"


@implementation SVHTMLGenerationContext

#pragma mark Stack

+ (SVHTMLGenerationContext *)currentContext
{
    SVHTMLGenerationContext *result = [[[[NSThread currentThread] threadDictionary] objectForKey:@"SVHTMLGenerationContextStack"] lastObject];
    return result;
}

+ (void)pushContext:(SVHTMLGenerationContext *)context
{
    NSMutableArray *stack = [[[NSThread currentThread] threadDictionary] objectForKey:@"SVHTMLGenerationContextStack"];
    if (!stack) stack = [NSMutableArray arrayWithCapacity:1];
    [stack addObject:context];
    [[[NSThread currentThread] threadDictionary] setObject:stack forKey:@"SVHTMLGenerationContextStack"];
}

+ (void)popContext
{
    NSMutableArray *stack = [[[NSThread currentThread] threadDictionary] objectForKey:@"SVHTMLGenerationContextStack"];
    if ([stack count] > 0) [stack removeLastObject];
}

#pragma mark Init

- (id)init
{
    [super init];
    _includeStyling = YES;
    return self;
}

#pragma mark Properties

@synthesize baseURL = _baseURL;
@synthesize includeStyling = _includeStyling;
@synthesize liveDataFeeds = _liveDataFeeds;

@synthesize generationPurpose = _generationPurpose;
- (BOOL)isPublishing
{
    BOOL result = ([self generationPurpose] != kGeneratingPreview &&
                   [self generationPurpose] != kGeneratingQuickLookPreview);
    return result;
}

@synthesize currentPage = _currentPage;
- (void)setCurrentPage:(KTAbstractPage *)page
{
    page = [page retain];
    [_currentPage release], _currentPage = page;
    
    [self setBaseURL:[page URL]];
}

@end
