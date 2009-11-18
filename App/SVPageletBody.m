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
@dynamic elements;

- (void)addElement:(SVBodyElement *)element;
{
    // TODO: Ensure the element is not already part of another group
    [self addElementsObject:element];
}

- (NSString *)HTMLString;
{
    //  Piece together each of our elements to generate the HTML
    NSMutableString *result = [NSMutableString string];
    
    SVBodyElement *startElement = [[self elements] anyObject];
    if (startElement)
    {
        [result appendString:[startElement HTMLString]];
        
        // Add on everything after the start element
        SVBodyElement *anElement;
        while (anElement = [startElement nextElement])
        {
            [result appendString:[anElement HTMLString]];
        }
        
        // Insert everything before the start element
        while (anElement = [startElement previousElement])
        {
            [result insertString:[anElement HTMLString] atIndex:0];
        }
    }
    
    
    return result;
}

@end
