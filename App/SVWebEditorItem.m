//
//  SVWebEditorItem.m
//  Sandvox
//
//  Created by Mike on 24/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorItem.h"

#import "SVBodyElement.h"


@interface SVWebEditorItemEnumerator : NSEnumerator
{
    NSEnumerator    *_iterator;
}

- (id)initWithItem:(SVWebEditorItem *)item;

@end


#pragma mark -



@implementation SVWebEditorItem

- (void)dealloc
{
    [self setChildWebEditorItems:nil];
    
    [super dealloc];
}

#pragma mark Accessors

- (SVWebEditorView *)webEditor
{
    return [[self parentWebEditorItem] webEditor];
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
    else
    {
        [children release];
    }
}

- (NSEnumerator *)enumerator;
{
    NSEnumerator *result = [[[SVWebEditorItemEnumerator alloc] initWithItem:self] autorelease];
    return result;
}

- (void)addDescendantsToMutableArray:(NSMutableArray *)descendants;
{
    [descendants addObjectsFromArray:[self childWebEditorItems]];
    [[self childWebEditorItems] makeObjectsPerformSelector:_cmd withObject:descendants];
}

#pragma mark Selection

- (BOOL)isSelectable;   // default is YES. Subclass for more complexity, shouldn't worry about KVO
{
    return YES;
}

- (BOOL)isEditable { return NO; }

- (NSArray *)selectableAncestors;
{
    NSMutableArray *result = [NSMutableArray array];
    
    SVWebEditorItem *aParentItem = [self parentWebEditorItem];
    while (aParentItem)
    {
        if ([aParentItem isSelectable]) [result addObject:aParentItem];
        aParentItem = [aParentItem parentWebEditorItem];
    }
    
    return result;
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
    
    return result;
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

#pragma mark Resizing

- (unsigned int)resizingMask; { return 0; }

- (NSInteger)resizeByMovingHandle:(SVGraphicHandle)handle toPoint:(NSPoint)point;
{    
    SUBCLASSMUSTIMPLEMENT;
    [self doesNotRecognizeSelector:_cmd];
    return handle;
}

#pragma mark Debugging

- (NSString *)descriptionWithIndent:(NSUInteger)level
{
    // Indent
    NSString *indent = [@"" stringByPaddingToLength:level withString:@"\t" startingAtIndex:0];
    
    // Standard
    NSString *result = [indent stringByAppendingString:[super description]];
                        
    NSString *blurb = [self blurb];
    if (blurb) result = [result stringByAppendingFormat:@" %@", blurb];
    
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

- (NSString *)blurb
{
    return nil;
}

@end


#pragma mark -


@implementation SVWebEditorItemEnumerator

- (id)initWithItem:(SVWebEditorItem *)item;
{
    [self init];
    
    // For now, the easy thing is to cheat and gather everything up into a single array immediately, and enumerate that
    NSMutableArray *items = [[NSMutableArray alloc] init];
    [item addDescendantsToMutableArray:items];
    
    _iterator = [[items objectEnumerator] retain];
    [items release];
    
    return self;
}

- (void)dealloc
{
    [_iterator release];
    
    [super dealloc];
}

- (id)nextObject { return [_iterator nextObject]; }

- (NSArray *)allObjects { return [_iterator allObjects]; }

@end

