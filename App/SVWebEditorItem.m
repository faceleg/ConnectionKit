//
//  SVWebEditorItem.m
//  Sandvox
//
//  Created by Mike on 24/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorItem.h"

#import "SVBodyElement.h"


@implementation SVWebEditorItem

- (void)dealloc
{
    [self setChildWebEditorItems:nil];
    
    [super dealloc];
}

#pragma mark Accessors

- (BOOL)isEditable { return NO; }

- (SVWebEditorView *)webEditorView
{
    return [[self parentWebEditorItem] webEditorView];
}

#pragma mark Tree

/*  Fairly basic heirarchy maintenance stuff here
 */

@synthesize childWebEditorItems = _childControllers;
- (void)setChildWebEditorItems:(NSArray *)controllers
{
    [[self childWebEditorItems] makeObjectsPerformSelector:@selector(setParentWebEditorItem:)
                                                withObject:nil];
    
    controllers = [controllers copy];
    [_childControllers release]; _childControllers = controllers;
    
    [controllers makeObjectsPerformSelector:@selector(setParentWebEditorItem:)
                                 withObject:self];
}

@synthesize parentWebEditorItem = _parentController;

- (void)addChildWebEditorItem:(SVWebEditorItem *)controller;
{
    OBPRECONDITION(controller);
    
    NSArray *children = [[self childWebEditorItems] arrayByAddingObject:controller];
    if (!children) children = [NSArray arrayWithObject:controller];
    [_childControllers release]; _childControllers = [children copy];
    
    [controller setParentWebEditorItem:self];
}

- (void)removeFromParentWebEditorItem;
{
    [self setParentWebEditorItem:nil];
    
    SVWebEditorItem *parent = [self parentWebEditorItem];
    
    NSMutableArray *children = [[parent childWebEditorItems] mutableCopy];
    [children removeObject:self];
    
    if (parent)
    {
        [parent->_childControllers release]; parent->_childControllers = children;
    }
}

#pragma mark Searching the Tree

- (SVWebEditorItem *)childItemForDOMNode:(DOMNode *)node;
{
    OBPRECONDITION(node);
    
    SVWebEditorItem *result = nil;
    NSArray *childItemDOMNodes = [[self childWebEditorItems] valueForKey:@"HTMLElement"];
    
    DOMNode *aNode = node;
    while (aNode)
    {
        NSUInteger index = [childItemDOMNodes indexOfObjectIdenticalTo:aNode];
        if (index != NSNotFound)
        {
            result = [[self childWebEditorItems] objectAtIndex:index];
            break;
        }
        aNode = [aNode parentNode];
    }
    
    return result;
}

- (SVWebEditorItem *)descendantItemForDOMNode:(DOMNode *)node;
{
    OBPRECONDITION(node);
    
    SVWebEditorItem *result = [self childItemForDOMNode:node];
    if (result)
    {
        result = [result descendantItemForDOMNode:node];
    }
    else
    {
        result = self;
    }
    
    return self;
}

- (SVWebEditorItem *)descendantItemWithRepresentedObject:(id)object;
{
    OBPRECONDITION(object);
    
    id result = ([[self representedObject] isEqual:object] ? self : nil);
    if (!result)
    {
        for (SVWebEditorItem *anItem in [self childWebEditorItems])
        {
            result = [anItem descendantItemWithRepresentedObject:object];
            if (result) break;
        }
    }
    
    return result;
}

#pragma mark Debugging

- (NSString *)descriptionWithIndent:(NSUInteger)level
{
    // Indent
    NSString *result = [@"" stringByPaddingToLength:level withString:@"\t" startingAtIndex:0];
    
    // Standard
    result = [result stringByAppendingString:[super description]];
    
    // Children
    for (SVWebEditorItem *anItem in [self childWebEditorItems])
    {
        result = [result stringByAppendingFormat:
                  @"\n%@",
                  [anItem descriptionWithIndent:(level + 1)]];
    }
    
    return result;
}

- (NSString *)description
{
    return [self descriptionWithIndent:0];
}

@end
