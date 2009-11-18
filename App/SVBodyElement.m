// 
//  SVBodyElement.m
//  Sandvox
//
//  Created by Mike on 18/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVBodyElement.h"

#import "SVPageletBody.h"


@interface SVBodyElement ()
@property(nonatomic, retain, readwrite) SVBodyElement *previousElement;
@property(nonatomic, retain, readwrite) SVBodyElement *nextElement;
@end


#pragma mark -


@implementation SVBodyElement 

@dynamic body;
@dynamic previousElement;
@dynamic nextElement;

- (void)insertAfterElement:(SVBodyElement *)element;
{
    [self removeFromElementsList];
    
    [self setNextElement:[element nextElement]];
    [element setNextElement:self];
}

- (void)insertBeforeElement:(SVBodyElement *)element;
{
    [self removeFromElementsList];
    
    [self setPreviousElement:[element previousElement]];
    [element setPreviousElement:self];
}

- (void)removeFromElementsList;
{
    // Core Data will take care of the inverse relationships, so this one line is enough to remove from the list
    [[self previousElement] setNextElement:[self nextElement]];
}

- (NSString *)HTMLString;
{
    SUBCLASSMUSTIMPLEMENT;
    return nil;
}

@end
