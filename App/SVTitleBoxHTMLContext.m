//
//  SVTitleBoxHTMLContext.m
//  Sandvox
//
//  Created by Mike on 10/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVTitleBoxHTMLContext.h"
#import "SVBodyParagraph.h"

#import "DOMNode+Karelia.h"
#import "DOMElement+Karelia.h"


@interface SVTitleBoxHTMLContext ()

- (DOMNode *)replaceDOMElementIfNeeded:(DOMElement *)element;

- (DOMElement *)changeDOMElement:(DOMElement *)element toTagName:(NSString *)tagName;
- (DOMNode *)unlinkDOMElementBeforeWriting:(DOMElement *)element;
- (void)populateSpanElementAttributes:(DOMElement *)span
                      fromFontElement:(DOMHTMLFontElement *)fontElement;

@end


#pragma mark -


@interface DOMNode (SVTitleBoxHTMLContext)
- (void)flattenNodesAfterChild:(DOMNode *)aChild;

- (BOOL)isParagraphCharacterStyle;  // returns YES unless the receiver is text, <a>, <br>, image etc.

- (BOOL)isParagraphContent;     // returns YES if the receiver is text, <br>, image etc.

- (DOMNode *)nodeByStrippingNonParagraphNodes:(SVTitleBoxHTMLContext *)context;

@end


#pragma mark -


@implementation SVTitleBoxHTMLContext

- (id)initWithMutableString:(NSMutableString *)string
{
    self = [super initWithMutableString:string];
    
    _unwrittenDOMElements = [[NSMutableArray alloc] init];
    
    return self;
}

- (void)dealloc
{
    [_unwrittenDOMElements release];
    
    [super dealloc];
}

#pragma mark Elements

- (DOMNode *)writeDOMElement:(DOMElement *)element;
{
    // Remove any tags not allowed.
    DOMNode *replacement = [self replaceDOMElementIfNeeded:element];
    if (replacement != element)
    {
        // Pretend to the caller that the element got written (which it didn't) and that the next node to write is the replacement
        return replacement;
    }
    
    
    
    
    // Can't allow nested elements. e.g.    <span><span>foo</span> bar</span>   is wrong and should be simplified.
    NSString *tagName = [element tagName];
    if ([self hasOpenElementWithTagName:tagName])
    {
        // Shuffle up following nodes
        DOMElement *parent = (DOMElement *)[element parentNode];
        [parent flattenNodesAfterChild:element];
        
        
        // It make take several moves up the tree till we find the conflicting element
        while (![[parent tagName] isEqualToString:tagName])
        {
            // Move element across to a clone of its parent
            DOMNode *clone = [parent cloneNode:NO];
            [[parent parentNode] insertBefore:clone refChild:[parent nextSibling]];
            [clone appendChild:element];
            parent = (DOMElement *)[parent parentNode];
        }
        
        
        // Now we're ready to flatten the conflict
        [element copyInheritedStylingFromElement:parent];
        [[parent parentNode] insertBefore:element refChild:[parent nextSibling]];
        
        
        // Pretend we wrote the element and are now finished. Recursion will take us back to the element in its new location to write it for real
        return nil;
    }
    
    
    
    
    //  The element might turn out to be empty...
    if ([element isParagraphContent])
    {
        return [super writeDOMElement:element];
    }
    else
    {
        // ..so push onto the stack, ready to write if requested
        [_unwrittenDOMElements addObject:element];
        
        // Write inner HTML
        [element writeInnerHTMLToContext:self];
        
        // If there was no actual content inside the element, then it should be thrown away. We can tell this by examining the stack
        if ([_unwrittenDOMElements lastObject] == element)
        {
            DOMNode *result = [element nextSibling];
            
            [[element parentNode] removeChild:element];
            [_unwrittenDOMElements removeLastObject];
            
            return result;
        }
        else
        {
            // Close the element, but first, if the next sibling is equal, merge it with this one
            DOMNode *result = [[element nextSibling] nodeByStrippingNonParagraphNodes:self];
            
            while ([result isEqualNode:element compareChildNodes:NO])
            {
                DOMNode *startNode = [result firstChild];
                
                // Move elements out of sibling and into original
                [[element mutableChildNodesArray] addObjectsFromArray:[result mutableChildNodesArray]];
                
                // Dump the now uneeded node
                [[result parentNode] removeChild:result];
                
                // Carry on writing
                if (startNode) [element writeInnerHTMLStartingWithNode:startNode toContext:self];
                
                
                // Recurse in case the next node after that also fits the criteria
                result = [[element nextSibling] nodeByStrippingNonParagraphNodes:self];
            }
            
            
            
            
            [self writeEndTag];
            
            return result;
        }
    }
}

- (DOMNode *)replaceDOMElementIfNeeded:(DOMElement *)element;
{
    DOMNode *result = element;
    NSString *tagName = [element tagName];
    
    
    // Remove any tags not allowed. Repeat cycle for the node that takes its place
    if (![[self class] validateTagName:tagName])
    {
        // Convert a bold or italic tag to <strong> or <em>
        if ([tagName isEqualToString:@"B"] ||
            [element isKindOfClass:[DOMHTMLHeadingElement class]])
        {
            result = [self changeDOMElement:element toTagName:@"STRONG"];
        }
        else if ([tagName isEqualToString:@"I"])
        {
            result = [self changeDOMElement:element toTagName:@"EM"];
        }
        // Convert a <font> tag to <span> with appropriate styling
        else if ([tagName isEqualToString:@"FONT"])
        {
            result = [self changeDOMElement:element toTagName:@"SPAN"];
            
            [self populateSpanElementAttributes:(DOMHTMLElement *)result
                      fromFontElement:(DOMHTMLFontElement *)element];
        }
        else
        {
            // Everything else gets removed, or replaced with a <span> with appropriate styling
            if ([[element style] length] > 0)
            {
                DOMElement *replacement = [self changeDOMElement:element toTagName:@"SPAN"];
                [replacement copyInheritedStylingFromElement:element];
                
                result = replacement;
            }
            else
            {
                result = [self unlinkDOMElementBeforeWriting:element];
            }
            
            
            
        }
        
        result = [result nodeByStrippingNonParagraphNodes:self];
    }
    
    return result;
}

- (DOMElement *)changeDOMElement:(DOMElement *)element toTagName:(NSString *)tagName;
{
    //WebView *webView = [[[element ownerDocument] webFrame] webView];
    
    DOMElement *result = [[element parentNode] replaceChildNode:element
                                      withElementWithTagName:tagName
                                                moveChildren:YES];
    
    return result;
}

- (DOMNode *)unlinkDOMElementBeforeWriting:(DOMElement *)element
{
    //  Called when the element hasn't fitted the whitelist. Unlinks it, and returns the correct node to write
    // Figure out the preferred next node
    DOMNode *result = [element firstChild];
    if (!result) result = [element nextSibling];
    
    // Remove non-whitelisted element
    [element unlink];
    
    
    return result;
}

#pragma mark Element Attributes

- (void)openTagWithDOMElement:(DOMElement *)element;    // open the tag and write attributes
{
    // Open tag
    [self openTag:[element tagName]];
    
    // Write attributes
    DOMNamedNodeMap *attributes = [element attributes];
    NSUInteger index;
    for (index = 0; index < [attributes length]; index++)
    {
        // Check each attribute should be written
        DOMAttr *anAttribute = (DOMAttr *)[attributes item:index];
        NSString *attributeName = [anAttribute name];
        
        if ([self validateAttribute:attributeName])
        {
            // Validate individual styling
            if ([attributeName isEqualToString:@"style"])
            {
                [self removeUnsupportedCustomStyling:[element style]];
            }
            
            // Now it's OK to persist
            [self writeAttribute:attributeName value:[anAttribute value]];
        }
        else
        {
            [attributes removeNamedItem:attributeName];
            index--;
        }
    }
}

- (void)populateSpanElementAttributes:(DOMElement *)span
                      fromFontElement:(DOMHTMLFontElement *)fontElement;
{
    [[span style] setProperty:@"font-family" value:[fontElement face] priority:@""];
    [[span style] setProperty:@"color" value:[fontElement color] priority:@""];
    // Ignoring size for now, but may have to revisit
}

#pragma mark High-level Writing

// Comments have no place in text fields! Yes, they get left in the DOM until it's replaced, but you can't see them, so no harm done
- (void)writeComment:(NSString *)comment; { }

#pragma mark Primitive Writing

- (void)writeString:(NSString *)string
{
    // Before actually writing the string, push through any pending Elements
    if ([_unwrittenDOMElements count] > 0)
    {
        NSArray *elements = [_unwrittenDOMElements copy];
        [_unwrittenDOMElements removeAllObjects];
        
        for (DOMElement *anElement in elements)
        {
            [self openTagWithDOMElement:anElement];
            [self closeStartTag];
        }
    }
    
    
    // Do the writing
    [super writeString:string];
}

- (BOOL)hasOpenElementWithTagName:(NSString *)tagName
{
    tagName = [tagName uppercaseString];
    
    for (DOMElement *anElement in _unwrittenDOMElements)
    {
        if ([[anElement tagName] isEqualToString:tagName]) return YES;
    }
    
    return [super hasOpenElementWithTagName:tagName];
}

#pragma mark Tag Whitelist

+ (BOOL)validateTagName:(NSString *)tagName;
{
    BOOL result = ([tagName isEqualToString:@"SPAN"] ||
                   [tagName isEqualToString:@"STRONG"] ||
                   [tagName isEqualToString:@"EM"] ||
                   [self isElementWithTagNameContent:tagName] ||
                   [tagName isEqualToString:@"SUP"] ||
                   [tagName isEqualToString:@"SUB"]);
    
    return result;
}

+ (BOOL)isElementWithTagNameContent:(NSString *)tagName;
{
    BOOL result = ([tagName isEqualToString:@"BR"]);
    
    return result;
}

#pragma mark Attribute Whitelist

- (BOOL)validateAttribute:(NSString *)attributeName;
{
    BOOL result = NO;
    
    // Allow class and style on any element except <br>
    NSString *tagName = [self lastOpenElementTagName];
    if (tagName && ![tagName isEqualToString:@"BR"])
    {
        result = ([attributeName isEqualToString:@"class"] ||
                  [attributeName isEqualToString:@"style"]);
    }
    
    return result;
}

#pragma mark Styling Whitelist

- (BOOL)validateStyleProperty:(NSString *)propertyName;
{
    BOOL result = ([propertyName isEqualToString:@"font"] ||
                   [propertyName hasPrefix:@"font-"] ||
                   [propertyName isEqualToString:@"color"] ||
                   [propertyName isEqualToString:@"text-decoration"]);
    
    return result;
}

- (void)removeUnsupportedCustomStyling:(DOMCSSStyleDeclaration *)style;
{
    for (int i = 0; i < [style length]; i++)
    {
        NSString *propertyName = [style item:i];
        if (![self validateStyleProperty:propertyName])
        {
            [style removeProperty:propertyName];
            i--;
        }
    }
}

@end


#pragma mark -


@implementation DOMNode (SVTitleBoxHTMLContext)

- (BOOL)isParagraphCharacterStyle; { return NO; }

- (void)flattenNodesAfterChild:(DOMNode *)aChild;
{
    // It doesn't make sense to flatten the *entire* contents of a node, so should always have a child to start from
    OBPRECONDITION(aChild);
    
    
    // Make a copy of ourself to flatten into
    DOMNode *clone = [self cloneNode:NO];
    [[self parentNode] insertBefore:clone refChild:[self nextSibling]];
    
    
    // Flatten everything after aChild so it appears alongside ourself somewhere. Work backwards so order is maintained
    DOMNode *aNode;
    while ((aNode = [self lastChild]) && aNode != aChild)
    {
        [clone insertBefore:aNode refChild:[clone firstChild]];
    }
}

- (BOOL)isParagraphContent; { return NO; }

- (DOMNode *)nodeByStrippingNonParagraphNodes:(SVTitleBoxHTMLContext *)context; { return self; }

@end

@implementation DOMElement (SVTitleBoxHTMLContext)

- (BOOL)isParagraphCharacterStyle; { return YES; }

- (BOOL)isParagraphContent;
{
    BOOL result = [SVTitleBoxHTMLContext isElementWithTagNameContent:[self tagName]];
    return result;
}

- (DOMNode *)nodeByStrippingNonParagraphNodes:(SVTitleBoxHTMLContext *)context;
{
    return [context replaceDOMElementIfNeeded:self];
}

@end
        

@implementation DOMHTMLBRElement (SVTitleBoxHTMLContext)
- (BOOL)isParagraphCharacterStyle; { return NO; }
@end

@implementation DOMHTMLAnchorElement (SVTitleBoxHTMLContext)
- (BOOL)isParagraphCharacterStyle; { return NO; }
@end

@implementation DOMCharacterData (SVTitleBoxHTMLContext)
- (BOOL)isParagraphContent; { return YES; }
@end
