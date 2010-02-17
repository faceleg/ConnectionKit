//
//  SVBodyTextHTMLContext.m
//  Sandvox
//
//  Created by Mike on 10/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVBodyTextHTMLContext.h"

#import "SVBodyTextDOMController.h"


@implementation SVBodyTextHTMLContext

- (void)dealloc
{
    [_DOMController release];
    [super dealloc];
}

+ (BOOL)validateTagName:(NSString *)tagName
{
    BOOL result = ([tagName isEqualToString:@"A"] ||
                   [super validateTagName:tagName]);
    
    return result;
}

- (BOOL)validateAttribute:(NSString *)attributeName;
{
    // Super doesn't allow links; we do.
    if ([[self lastOpenElementTagName] isEqualToString:@"A"])
    {
        BOOL result = ([attributeName isEqualToString:@"href"] ||
                       [attributeName isEqualToString:@"target"] ||
                       [attributeName isEqualToString:@"style"] ||
                       [attributeName isEqualToString:@"charset"] ||
                       [attributeName isEqualToString:@"hreflang"] ||
                       [attributeName isEqualToString:@"name"] ||
                       [attributeName isEqualToString:@"title"] ||
                       [attributeName isEqualToString:@"rel"] ||
                       [attributeName isEqualToString:@"rev"]);
        
        return result;               
    }
    else
    {
        return [super validateAttribute:attributeName];
    }
}

- (DOMNode *)writeDOMElement:(DOMElement *)element
{
    NSArray *graphicNodes = [[[self bodyTextDOMController] graphicControllers] valueForKey:@"HTMLElement"];
    
    if ([graphicNodes containsObject:element])
    {
        return [element nextSibling];
    }
    else
    {
        return [super writeDOMElement:element];
    }
}

- (DOMNode *)replaceDOMElementIfNeeded:(DOMElement *)element;
{
    NSString *tagName = [element tagName];
    
    
    // If a paragraph ended up here, treat it like normal, but then push all nodes following it out into new paragraphs
    if ([tagName isEqualToString:@"P"])
    {
        return element;
        
        DOMNode *parent = [element parentNode];
        DOMNode *refNode = element;
        while (parent)
        {
            [parent flattenNodesAfterChild:refNode];
            if ([[(DOMElement *)parent tagName] isEqualToString:@"P"]) break;
            refNode = parent; parent = [parent parentNode];
        }
    }
    
    
    return [super replaceDOMElementIfNeeded:element];
}

#pragma mark Properties

@synthesize bodyTextDOMController = _DOMController;

@end
