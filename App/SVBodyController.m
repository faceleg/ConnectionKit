//
//  SVBodyController.m
//  Sandvox
//
//  Created by Mike on 23/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVBodyController.h"

#import "SVBodyParagraph.h"

#import "NSArray+Karelia.h"


@implementation SVBodyController

- (id)newObject
{
    SVBodyParagraph *result = [NSEntityDescription insertNewObjectForEntityForName:@"BodyParagraph"
                                                            inManagedObjectContext:[self managedObjectContext]];
    
    return [result retain];
}

- (NSArray *)arrangeObjects:(NSArray *)objects
{
    // Arrange using the linked list
    NSArray *result = [NSArray arrayWithDoublyLinkedListObject:[objects lastObject]
                                            nextObjectSelector:@selector(nextElement)
                                        previousObjectSelector:@selector(previousElement)];
    
    return result;
}

- (NSArray *)automaticRearrangementKeyPaths
{
    NSArray *result = [NSArray arrayWithObjects:@"nextElement", @"previousElement", nil];
    
    NSArray *otherKeyPaths = [super automaticRearrangementKeyPaths];
    if ([otherKeyPaths count] > 0)
    {
        result = [result arrayByAddingObjectsFromArray:otherKeyPaths];
    }
    
    return result;
}

- (void)insertObject:(SVBodyElement *)element atArrangedObjectIndex:(NSUInteger)index
{
    // First insert into linked list
    [element insertAfterElement:[[self arrangedObjects] objectAtIndex:(index - 1)]];
    
    [[self managedObjectContext] processPendingChanges];
    [super insertObject:element atArrangedObjectIndex:index];
}

- (void)removeObject:(SVBodyElement *)element
{
    [super removeObject:element];
    [[self managedObjectContext] processPendingChanges];
    
    // Then remove from linked list
    [element removeFromElementsList];
}

@end
