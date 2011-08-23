//
//  SVWebViewSelectionController.m
//  Sandvox
//
//  Created by Mike on 21/08/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVWebViewSelectionController.h"

#import "DOMNode+Karelia.h"
#import "DOMRange+Karelia.h"


@implementation SVWebViewSelectionController

- (void)dealloc
{
    [_selection release];
    
    [super dealloc];
}

@synthesize selection = _selection;
+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key;
{
    if ([key isEqualToString:@"listIndentLevel"] ||
        [key isEqualToString:@"shallowestListIndentLevel"] ||
        [key isEqualToString:@"listTypeTag"])
    {
        return [NSSet setWithObject:@"selection"];
    }
    else
    {
        return [super keyPathsForValuesAffectingValueForKey:key];
    }
}

+ (NSSet *)listTagNames;
{
    static NSSet *listTags;
    if (!listTags) listTags = [[NSSet alloc] initWithObjects:@"UL", @"OL", nil];
    return listTags;
}

#pragma mark Indentation

- (NSNumber *)listIndentLevel;
{
    if (!_selection) return NSNoSelectionMarker;
    
    
    // How many levels deep is the selection?
    NSNumber *result = [self shallowestListIndentLevel];
    
    
    // Does it contain sub-lists?
    id ancestor = [_selection commonAncestorContainer];
    while (![ancestor respondsToSelector:@selector(getElementsByTagName:)])
    {
        ancestor = [ancestor parentNode];
    }
    
    DOMNodeList *nodes = [ancestor getElementsByTagName:@"UL"];
    NSUInteger i, count = [nodes length];
    
    for (i = 0; i < count; i++)
    {
        DOMNode *aNode = [nodes item:i];
        if ([_selection intersectsNode:aNode]) return NSMultipleValuesMarker;
    }
    
    nodes = [ancestor getElementsByTagName:@"OL"];
    count = [nodes length];
    
    for (i = 0; i < count; i++)
    {
        DOMNode *aNode = [nodes item:i];
        if ([_selection intersectsNode:aNode]) return NSMultipleValuesMarker;
    }
    
    
    return result;
}

- (NSNumber *)shallowestListIndentLevel;
{
    if (!_selection) return NSNoSelectionMarker;
    
    // How many levels deep is the selection?
    NSUInteger result = [self listIndentLevelForDOMNode:[_selection commonAncestorContainer]];
    return [NSNumber numberWithUnsignedInteger:result];
}

- (NSNumber *)deepestListIndentLevel;
{
    if (!_selection) return NSNoSelectionMarker;
    
    
    NSUInteger result = 0;
    
    // Get all the contained list elements
    id ancestor = [_selection commonAncestorContainer];
    while (![ancestor respondsToSelector:@selector(getElementsByTagName:)])
    {
        ancestor = [ancestor parentNode];
    }
    
    DOMNodeList *nodes = [ancestor getElementsByTagName:@"LI"];
    NSUInteger i, count = [nodes length];
    
    for (i = 0; i < count; i++)
    {
        DOMNode *aNode = [nodes item:i];
        if ([_selection intersectsNode:aNode])
        {
            NSUInteger level = [self listIndentLevelForDOMNode:aNode];
            if (level > result) result = level;
        }
    }
    
    
    return (result ? [NSNumber numberWithUnsignedInteger:result] : [self shallowestListIndentLevel]);
}

- (NSUInteger)listIndentLevelForDOMNode:(DOMNode *)node;
{
    
    NSUInteger result = 0;
    DOMElement *list = [node ks_ancestorWithTagNameInSet:[[self class] listTagNames]];
    while (list)
    {
        result++;
        list = [[list parentNode] ks_ancestorWithTagNameInSet:[[self class] listTagNames]];
    }
    
    return result;
}

#pragma mark Type

- (NSNumber *)listTypeTag
{
    if (!_selection) return NSNoSelectionMarker;
    
    
    // Inside a list?
    NSNumber *level = [self shallowestListIndentLevel];
    BOOL listOnly = ([level isKindOfClass:[NSNumber class]] && [level unsignedIntegerValue] > 0);
    
    // What list items are selected?
    NSArray *listItems = [_selection ks_intersectingElementsWithTagName:@"LI"];
    if (![listItems count]) return [NSNumber numberWithInt:0];
    if (!listOnly) return NSMultipleValuesMarker;
    
    // Multiple selection?
    NSUInteger result = [self listTypeTagForDOMNode:[listItems objectAtIndex:0]];
    
    NSUInteger i, count = [listItems count];
    for (i = 1; i < count; i++)
    {
        DOMElement *anElement = [listItems objectAtIndex:i];
        if ([self listTypeTagForDOMNode:anElement] != result) return NSMultipleValuesMarker;
    }
    
    return [NSNumber numberWithUnsignedInteger:result];
}

- (NSNumber *)isOrderedList;
{
    NSNumber *result = [self listTypeTag];
    if ([result isKindOfClass:[NSNumber class]])
    {
        result = NSBOOL([result unsignedIntegerValue] == 2);
    }
    return result;
}
+ (NSSet *)keyPathsForValuesAffectingIsOrderedList;
{
    return [NSSet setWithObject:@"listTypeTag"];
}


- (NSUInteger)listTypeTagForDOMNode:(DOMNode *)node;
{
    DOMElement *list = [node ks_ancestorWithTagNameInSet:[[self class] listTagNames]];
    if ([[list tagName] isEqualToString:@"UL"])
    {
        return 1;
    }
    else if ([[list tagName] isEqualToString:@"OL"])
    {
        return 2;
    }
    else
    {
        return 0;
    }
}

@end
