// 
//  SVPageletBody.m
//  Sandvox
//
//  Created by Mike on 18/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVPageletBody.h"

#import "SVPagelet.h"
#import "SVBodyElement.h"


@interface SVPageletBody (CoreDataGeneratedAccessors)
- (void)addElementsObject:(SVBodyElement *)value;
- (void)removeElementsObject:(SVBodyElement *)value;
- (void)addElements:(NSSet *)value;
- (void)removeElements:(NSSet *)value;
@end


#pragma mark -


@implementation SVPageletBody 

@dynamic pagelet;

#pragma mark Elements

@dynamic elements;

- (NSArray *)orderedElements;
{
    //  Piece together each of our elements to generate the HTML
    NSMutableArray *result = nil;
    
    NSSet *elements = [self elements];
    if (elements)
    {
        result = [NSMutableArray arrayWithCapacity:[elements count]];
        
        SVBodyElement *startElement = [elements anyObject];
        if (startElement)
        {
            [result addObject:startElement];
            
            // Add on everything after the start element
            SVBodyElement *anElement = startElement;
            while (anElement = [anElement nextElement])
            {
                [result addObject:startElement];
            }
            
            // Insert everything before the start element
            anElement = startElement;
            while (anElement = [anElement previousElement])
            {
                [result insertObject:anElement atIndex:0];
            }
        }
    }
    
    
    return result;
}

- (SVBodyElement *)firstElement;
{
    // Start with a random element and search backwards to the beginning
    SVBodyElement *result = [[self elements] anyObject];
    
    SVBodyElement *previousElement;
    while (previousElement = [result previousElement])
    {
        result = previousElement;
    }
    
    return result;
}

- (void)addElement:(SVBodyElement *)element;
{
    // TODO: Ensure the element is not already part of another group
    [self addElementsObject:element];
}

#pragma mark HTML

- (NSString *)HTMLString;
{
    //  Piece together each of our elements to generate the HTML
    NSMutableString *result = [NSMutableString string];
    
    SVBodyElement *startElement = [[self elements] anyObject];
    if (startElement)
    {
        [result appendString:[startElement HTMLString]];
        
        // Add on everything after the start element
        SVBodyElement *anElement = startElement;
        while (anElement = [anElement nextElement])
        {
            [result appendString:[anElement HTMLString]];
        }
        
        // Insert everything before the start element
        anElement = startElement;
        while (anElement = [anElement previousElement])
        {
            [result insertString:[anElement HTMLString] atIndex:0];
        }
    }
    
    
    return result;
}

- (void)updateWithHTMLElement:(DOMHTMLElement *)element;
{
    
}

@end
