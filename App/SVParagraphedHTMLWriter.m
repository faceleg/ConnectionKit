//
//  SVParagraphedHTMLWriter.m
//  Sandvox
//
//  Created by Mike on 10/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVParagraphedHTMLWriter.h"

#import "NSString+Karelia.h"
#import "DOMNode+Karelia.h"


@implementation SVParagraphedHTMLWriter

#pragma mark Init & Dealloc

- (id)initWithOutputStringWriter:(KSStringWriter *)stream;	// designated initializer
{
    if (self = [super initWithOutputStringWriter:stream])
    {
        _attachments = [[NSMutableSet alloc] init];
        [self setImportsGraphics:YES];
    }
    
    return self;
}

- (void)dealloc
{
    [_attachments release];
    [super dealloc];
}

#pragma mark Properties

@synthesize allowsPagelets = _allowsBlockGraphics;

#pragma mark Output

- (NSSet *)textAttachments; { return [[_attachments copy] autorelease]; }

- (void)writeTextAttachment:(SVTextAttachment *)attachment;
{
    [_attachments addObject:attachment];
    [self writeString:[NSString stringWithUnichar:NSAttachmentCharacter]];
}

#pragma mark Cleanup

- (DOMNode *)handleInvalidBlockElement:(DOMElement *)element;
{
    // Move the element and its next siblings up a level. Next stage of recursion will find them there
    
    
    DOMNode *parent = [element parentNode];
    DOMNode *newParent = [parent parentNode];
    NSArray *nodes = [parent childDOMNodesAfterChild:[element previousSibling]];
    
    [newParent insertDOMNodes:nodes beforeChild:[parent nextSibling]];
    
    
    return nil;
}

- (DOMNode *)handleInvalidDOMElement:(DOMElement *)element;
{
    // Ignore callout <div>s
    NSString *tagName = [element tagName];
    
    if ([tagName isEqualToString:@"DIV"] &&
        [[element className] hasPrefix:@"callout-container"])
    {
        return [element nextSibling];
    }
    
    
    // Completely invalid, or top-level elements should be converted into paragraphs
    else if ([self openElementsCount] == 0)
    {
        return [self changeDOMElement:element toTagName:@"P"];
    }
    
    
    // Non-top-level block elements should be converted into paragraphs higher up the tree
    else
    {
        DOMDocument *doc = [element ownerDocument];
        DOMCSSStyleDeclaration *style = [doc getComputedStyle:element pseudoElement:nil];
        if ([[style getPropertyValue:@"display"] isEqualToString:@"block"])
        {
            if ([[self class] validateElement:tagName])
            {
                return [self handleInvalidBlockElement:element];
            }
            else
            {
                return [self changeDOMElement:element toTagName:@"P"];
            }
        }
        else
        {
            return [super handleInvalidDOMElement:element];
        }
    }
}

#pragma mark Basic Writing

- (void)writeText:(NSString *)string;
{
    // At start of top element, ignore whitespace. #76588
    if ([self openElementsCount] == 1 &&
        [_pendingStartTagDOMElements count] &&
        [string isWhitespace])
    {
        return;
    }
    
    [super writeText:string];
}

#pragma mark Validation

- (BOOL)validateElement:(NSString *)tagName
{
    BOOL result;
    
    // Only a handul of block-level elements are supported. They can only appear at the top-level, or directly inside a list item
    if ([tagName isEqualToString:@"P"] ||
        [tagName isEqualToString:@"UL"] ||
        [tagName isEqualToString:@"OL"])
    {
        result = ([self openElementsCount] == 0 ||
                  [[self topElement] isEqualToStringCaseInsensitive:@"LI"]);
    }
    else
    {
        result = [super validateElement:tagName];
    }
    
    return result;
}

+ (BOOL)validateElement:(NSString *)tagName;    // can this sort of element ever be valid?
{
    BOOL result = ([super validateElement:tagName] ||
                   [tagName isEqualToString:@"P"] ||
                   [tagName isEqualToString:@"A"] ||
                   [tagName isEqualToString:@"UL"] ||
                   [tagName isEqualToString:@"OL"]);
    return result;
}

- (BOOL)validateAttribute:(NSString *)attributeName ofElementWithTagName:(NSString *)tagName;
{
    // Super doesn't allow links; we do.
    if ([tagName isEqualToString:@"A"])
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
        return [super validateAttribute:attributeName ofElementWithTagName:tagName];
    }
}

- (BOOL)validateStyleProperty:(NSString *)propertyName ofElementWithTagName:(NSString *)tagName;
{
    BOOL result = [super validateStyleProperty:propertyName ofElementWithTagName:tagName];
    
    if (!result && [propertyName isEqualToString:@"text-align"])
    {
        if ([tagName isEqualToString:@"p"])
        {
            result = YES;
        }
    }
    
    return result;
}

@end


#pragma mark -


@implementation DOMNode (SVBodyText)

- (DOMNode *)writeTopLevelParagraph:(KSHTMLWriter *)context;
{
    //  Don't want unknown nodes
    DOMNode *result = [self nextSibling];
    [[self parentNode] removeChild:self];
    return result;
}

@end


@implementation DOMElement (SVBodyText)

- (DOMNode *)writeTopLevelParagraph:(KSHTMLWriter *)writer;
{
    //  Elements can be treated pretty normally
    DOMNode *node = [writer willWriteDOMElement:self];
    if (node == self)
    {
        [writer startElement:[[self tagName] lowercaseString] withDOMElement:self];
        [writer writeInnerOfDOMNode:self];
        return [writer endElementWithDOMElement:self];
    }
    else
    {
        return node;
    }
}

@end


@implementation DOMText (SVBodyText)

- (DOMNode *)writeTopLevelParagraph:(KSHTMLWriter *)context;
{
    NSString *text = [self textContent];
    if ([text isWhitespace])
    {
        //  Only allowed  a single newline at the top level. Ignore whitespace at the very start of text
        DOMNode *previousNode = [self previousSibling];
        if (previousNode)
        {
            if ([previousNode nodeType] == DOM_TEXT_NODE)
            {
                return [super writeTopLevelParagraph:context];  // delete self
            }
            else
            {
                [self setTextContent:@"\n"];    // XML Writer will take care of writing its own whitespace
            }
        }
        
        return [self nextSibling];
    }
    else
    {
        // Create a paragraph to contain the text
        DOMDocument *doc = [self ownerDocument];
        DOMElement *paragraph = [doc createElement:@"P"];
        [[self parentNode] appendChild:paragraph];
        
        // Move content into the paragraph
        DOMNode *aNode;
        DOMNode *previousNode = [self previousSibling];
        while ((aNode = [paragraph previousSibling]) != previousNode)
        {
            [paragraph insertBefore:aNode refChild:[paragraph firstChild]];
        }
        
        return paragraph;
    }
}

@end


