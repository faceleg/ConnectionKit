//
//  SVWebViewSelectionController.m
//  Sandvox
//
//  Created by Mike on 21/08/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVWebViewSelectionController.h"


@implementation SVWebViewSelectionController

- (void)dealloc
{
    [_selection release];
    
    [super dealloc];
}

@synthesize selection = _selection;
+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key;
{
    if ([key isEqualToString:@"listIndentLevel"])
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
    NSUInteger ancestorListsCount = 0;
    DOMNode *aNode = [_selection commonAncestorContainer];
    
    while (aNode)
    {
        if ([aNode isKindOfClass:[DOMElement class]])
        {
            NSString *tagName = [(DOMElement *)aNode tagName];
            if ([tagName isEqualToString:@"UL"] || [tagName isEqualToString:@"OL"])
            {
                ancestorListsCount++;
            }
        }
        
        aNode = [aNode parentNode];
    }
    
    
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
    
    
    return [NSNumber numberWithUnsignedInteger:ancestorListsCount];
}

@end
