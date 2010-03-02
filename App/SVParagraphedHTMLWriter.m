//
//  SVParagraphedHTMLWriter.m
//  Sandvox
//
//  Created by Mike on 10/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVParagraphedHTMLWriter.h"

#import "SVBodyTextDOMController.h"
#import "SVGraphic.h"
#import "SVTextAttachment.h"


@interface SVFieldEditorHTMLWriter (SVParagraphedHTMLWriter)
- (DOMNode *)super_writeDOMElement:(DOMElement *)element;
@end


#pragma mark -


@implementation SVFieldEditorHTMLWriter (SVParagraphedHTMLWriter)
- (DOMNode *)super_writeDOMElement:(DOMElement *)element;
{
    return [super writeDOMElement:element];
}
@end


#pragma mark -


@implementation SVParagraphedHTMLWriter

#pragma mark Init & Dealloc

- (id)initWithStringWriter:(id <KSStringWriter>)stream;
{
    if (self = [super initWithStringWriter:stream])
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
    
    
    return [super writeDOMElement:element];
}

#pragma mark Cleanup

- (DOMNode *)handleInvalidDOMElement:(DOMElement *)element;
{
    // Invalid top-level elements should be converted into paragraphs
    if ([self openElementsCount] == 0)
    {
        DOMElement *result = [self changeDOMElement:element toTagName:@"P"];
        return result;  // pretend the element was written, but retry on this new node
    }
    else
    {
        return [super handleInvalidDOMElement:element];
    }
    
    /*NSString *tagName = [element tagName];
    
    
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
    }*/
}

#pragma mark Validation

- (BOOL)validateTagName:(NSString *)tagName
{
    // Paragraphs are permitted in body text
    if ([tagName isEqualToString:@"P"] ||
        [tagName isEqualToString:@"UL"] ||
        [tagName isEqualToString:@"OL"])
    {
        BOOL result = ([self openElementsCount] == 0);
        return result;
    }
    else
    {
        BOOL result = ([tagName isEqualToString:@"A"] ||
                       [super validateTagName:tagName]);
    
        return result;
    }
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


#pragma mark -


@implementation DOMNode (SVBodyText)

- (DOMNode *)topLevelBodyTextNodeWriteToStream:(KSHTMLWriter *)context;
{
    //  Don't want unknown nodes
    DOMNode *result = [self nextSibling];
    [[self parentNode] removeChild:self];
    return result;
}

@end


@implementation DOMElement (SVBodyText)

- (DOMNode *)topLevelBodyTextNodeWriteToStream:(KSHTMLWriter *)context;
{
    //  Elements can be treated pretty normally
    return [context writeDOMElement:self];
}

@end


@implementation DOMText (SVBodyText)

- (DOMNode *)topLevelBodyTextNodeWriteToStream:(KSHTMLWriter *)context;
{
    //  Only allowed  a single newline at the top level
    if ([[self previousSibling] nodeType] == DOM_TEXT_NODE)
    {
        return [super topLevelBodyTextNodeWriteToStream:context];  // delete self
    }
    else
    {
        [self setTextContent:@"\n"];
        [context writeNewline];
        return [self nextSibling];
    }
}

@end


