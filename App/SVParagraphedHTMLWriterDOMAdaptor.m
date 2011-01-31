//
//  SVParagraphedHTMLWriter.m
//  Sandvox
//
//  Created by Mike on 10/02/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVParagraphedHTMLWriterDOMAdaptor.h"

#import "NSString+Karelia.h"
#import "DOMNode+Karelia.h"


@implementation SVParagraphedHTMLWriterDOMAdaptor

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
    [[self XMLWriter] writeString:[NSString stringWithUnichar:NSAttachmentCharacter]];
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

- (NSDictionary *)dictionaryWithCSSStyle:(DOMCSSStyleDeclaration *)style
                                 tagName:(NSString *)tagName;
{
    int length = [style length];
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:length];
    
    for (int i = 0; i < length; i++)
    {
        NSString *property = [style item:i];
        if ([self validateStyleProperty:property ofElementWithTagName:tagName])
        {
            [result setObject:[style getPropertyValue:property] forKey:property];
        }
    }
    
    return result;
}

- (DOMElement *)convertElementToParagraph:(DOMElement *)element cachedComputedStyle:(DOMCSSStyleDeclaration *)style;
{
    if (!style) style = [[element ownerDocument] getComputedStyle:element pseudoElement:@""];
    
    
    // Swap the element for a <P>, trying to retain as much style as possible. #92641
    NSDictionary *oldStyle = [self dictionaryWithCSSStyle:style tagName:@"P"];
    DOMElement *result = [self replaceDOMElement:element withElementWithTagName:@"P"];
    
    DOMCSSStyleDeclaration *paragraphStyle = [[element ownerDocument] getComputedStyle:result
                                                                         pseudoElement:nil];
    
    for (NSString *aProperty in oldStyle)
    {
        NSString *aValue = [paragraphStyle getPropertyValue:aProperty];
        if (![aValue isEqualToString:[oldStyle objectForKey:aProperty]])
        {
            [[result style] setProperty:aProperty
                                  value:[oldStyle objectForKey:aProperty]
                               priority:@""];
        }
    }
    
    return result;
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
    else if ([[self XMLWriter] openElementsCount] == 0)
    {
        // Special case: Line breaks are permitted as the very last element
        // TODO: Rather than read ahead to next DOM element, use same technique as other tidy up and delete the element during a later pass
        if ([tagName isEqualToString:@"BR"] && ![element nextSiblingOfClass:[DOMElement class]])
        {
            return element; // so it gets written normally
        }
        else
        {
            return [self convertElementToParagraph:element cachedComputedStyle:nil];
        }
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
                return [self convertElementToParagraph:element cachedComputedStyle:style];
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
    if ([[self XMLWriter] openElementsCount] == 1 &&
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
        result = ([[self XMLWriter] openElementsCount] == 0 ||
                  [[[self XMLWriter] topElement] isEqualToStringCaseInsensitive:@"LI"]);
    }
    else
    {
        // Super allows standard inline elements. We only support them once inside a paragraph or similar
        if ([[self XMLWriter] openElementsCount] > 0)
        {
            result = [super validateElement:tagName];
        }
        else
        {
            // Line breaks are permitted at top-level though
            result = NO;
        }
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

- (DOMNode *)writeTopLevelParagraph:(SVParagraphedHTMLWriterDOMAdaptor *)context;
{
    //  Don't want unknown nodes
    DOMNode *result = [self nextSibling];
    [[self parentNode] removeChild:self];
    return result;
}

@end


@implementation DOMElement (SVBodyText)

- (DOMNode *)writeTopLevelParagraph:(SVParagraphedHTMLWriterDOMAdaptor *)writer;
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

- (DOMNode *)writeTopLevelParagraph:(SVParagraphedHTMLWriterDOMAdaptor *)context;
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


