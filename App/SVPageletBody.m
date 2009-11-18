// 
//  SVPageletBody.m
//  Sandvox
//
//  Created by Mike on 18/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVPageletBody.h"

#import "SVPagelet.h"


@interface SVPageletBody (CoreDataGeneratedAccessors)
- (void)addElementsObject:(SVBodyElement *)value;
- (void)removeElementsObject:(SVBodyElement *)value;
- (void)addElements:(NSSet *)value;
- (void)removeElements:(NSSet *)value;
@end


#pragma mark -


@implementation SVPageletBody 

@dynamic pagelet;
@dynamic elements;

- (void)addElement:(SVBodyElement *)element;
{
    // TODO: Ensure the element is not already part of another group
    [self addElementsObject:element];
}

@end
