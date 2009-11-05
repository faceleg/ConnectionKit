//
//  SVWebEditorHTMLContext.m
//  Sandvox
//
//  Created by Mike on 05/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorHTMLContext.h"

#import "KTTemplateParser.h"

#import "KSObjectKeyPathPair.h"


@implementation SVWebEditorHTMLContext

- (id)init
{
    [super init];
    _objectKeyPathPairs = [[NSMutableSet alloc] init];
    return self;
}

- (void)dealloc
{
    [_objectKeyPathPairs release];
    
    [super dealloc];
}

- (void)addDependencyOnObject:(NSObject *)object keyPath:(NSString *)keyPath;
{
    [super addDependencyOnObject:object keyPath:keyPath];
    
    
    KSObjectKeyPathPair *pair = [[KSObjectKeyPathPair alloc] initWithObject:object
                                                                    keyPath:keyPath];
    [self addDependency:pair];
    [pair release];
}

- (void)addDependency:(KSObjectKeyPathPair *)pair;
{
    OBASSERT(_objectKeyPathPairs);
    
    // Ignore parser properties
    if (![[pair object] isKindOfClass:[KTTemplateParser class]])
    {
        [_objectKeyPathPairs addObject:pair];
    }
}

- (NSSet *)dependencies { return [[_objectKeyPathPairs copy] autorelease]; }

@end
