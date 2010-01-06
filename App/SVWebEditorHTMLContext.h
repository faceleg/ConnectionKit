//
//  SVWebEditorHTMLContext.h
//  Sandvox
//
//  Created by Mike on 05/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVMutableStringHTMLContext.h"


@class KSObjectKeyPathPair;
@interface SVWebEditorHTMLContext : SVMutableStringHTMLContext
{
    NSMutableSet    *_objectKeyPathPairs;
}

- (void)addDependency:(KSObjectKeyPathPair *)pair;
@property(nonatomic, copy, readonly) NSSet *dependencies;

@end