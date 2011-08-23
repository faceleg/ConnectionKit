//
//  SVWebViewSelectionController.m
//  Sandvox
//
//  Created by Mike on 21/08/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVWebViewSelectionController.h"

#import "DOMNode+Karelia.h"


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
        [key isEqualToString:@"shallowestListIndentLevel"])
    {
        return [NSSet setWithObject:@"selection"];
    }
    else
    {
        return [super keyPathsForValuesAffectingValueForKey:key];
    }
}

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

- (NSUInteger)listIndentLevelForDOMNode:(DOMNode *)node;
{
    static NSSet *listTags;
    if (!listTags) listTags = [[NSSet alloc] initWithObjects:@"UL", @"OL", nil];
    
    NSUInteger result = 0;
    DOMElement *list = [node ks_ancestorWithTagNameInSet:listTags];
    while (list)
    {
        result++;
        list = [[list parentNode] ks_ancestorWithTagNameInSet:listTags];
    }
    
    return result;
}

@end
