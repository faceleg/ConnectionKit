//
//  SVBodyTextHTMLContext.m
//  Sandvox
//
//  Created by Mike on 10/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVBodyTextHTMLContext.h"

#import "SVBodyTextDOMController.h"
#import "SVGraphic.h"
#import "SVTextAttachment.h"


@interface SVFieldEditorHTMLStream (SVBodyTextHTMLContext)
- (DOMNode *)super_writeDOMElement:(DOMElement *)element;
@end


#pragma mark -


@implementation SVFieldEditorHTMLStream (SVBodyTextHTMLContext)
- (DOMNode *)super_writeDOMElement:(DOMElement *)element;
{
    return [super writeDOMElement:element];
}
@end


#pragma mark -


@implementation SVBodyTextHTMLContext

#pragma mark Init & Dealloc

- (id)initWithStringStream:(id <KSStringOutputStream>)stream;
{
    if (self = [super initWithStringStream:stream])
    {
        _attachments = [[NSMutableSet alloc] init];
    }
    
    return self;
}

- (void)dealloc
{
    [_attachments release];
    [_DOMController release];
    [super dealloc];
}

#pragma mark Output

- (NSSet *)textAttachments; { return [[_attachments copy] autorelease]; }

#pragma mark Writing

- (DOMNode *)writeDOMElement:(DOMElement *)element
{
    NSArray *graphicControllers = [[self bodyTextDOMController] graphicControllers];
    
    for (SVDOMController *aController in graphicControllers)
    {
        if ([aController HTMLElement] == element)
        {
            [[self bodyTextDOMController] writeGraphicController:aController toContext:self];
            [_attachments addObject:[[aController representedObject] textAttachment]];
            
            return [element nextSibling];
        }
    }
    
    
    // Paragraphs are permitted in body text
    if ([[element tagName] isEqualToString:@"P"])
    {
        return [self super_writeDOMElement:element];
    }
    
   
    return [super writeDOMElement:element];
}

#pragma mark Cleanup

- (DOMNode *)handleInvalidDOMElement:(DOMElement *)element;
{
    NSString *tagName = [element tagName];
    
    
    // If a paragraph ended up here, treat it like normal, but then push all nodes following it out into new paragraphs
    if ([tagName isEqualToString:@"P"])
    {
        DOMNode *parent = [element parentNode];
        DOMNode *refNode = element;
        while (parent)
        {
            [parent flattenNodesAfterChild:refNode];
            if ([[(DOMElement *)parent tagName] isEqualToString:@"P"]) break;
            refNode = parent; parent = [parent parentNode];
        }
    }
    
    
    return [super handleInvalidDOMElement:element];
}

#pragma mark Validation

- (BOOL)validateTagName:(NSString *)tagName
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

- (BOOL)validateStyleProperty:(NSString *)propertyName;
{
    BOOL result = [super validateStyleProperty:propertyName];
    
    if (!result && [propertyName isEqualToString:@"text-align"])
    {
        NSString *tagName = [self lastOpenElementTagName];
        if ([tagName isEqualToString:@"P"])
        {
            result = YES;
        }
    }
    
    return result;
}

#pragma mark Properties

@synthesize bodyTextDOMController = _DOMController;

@end
