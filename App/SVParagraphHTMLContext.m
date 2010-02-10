//
//  SVParagraphHTMLContext.m
//  Sandvox
//
//  Created by Mike on 10/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVParagraphHTMLContext.h"
#import "SVBodyParagraph.h"

#import "DOMNode+Karelia.h"
#import "DOMElement+Karelia.h"


@interface SVParagraphHTMLContext ()

- (DOMNode *)replaceElementIfNeeded:(DOMElement *)element;

- (DOMElement *)changeElement:(DOMElement *)element toTagName:(NSString *)tagName;
- (DOMNode *)unlinkDOMElementBeforeWriting:(DOMElement *)element;
- (void)populateSpanElement:(DOMElement *)span
            fromFontElement:(DOMHTMLFontElement *)fontElement;

@end


#pragma mark -


@interface DOMNode (SVParagraphHTMLContext)
- (void)flattenNodesAfterChild:(DOMNode *)aChild;

- (BOOL)isParagraphCharacterStyle;  // returns YES unless the receiver is text, <a>, <br>, image etc.

- (BOOL)isParagraphContent;     // returns YES if the receiver is text, <br>, image etc.
- (BOOL)hasParagraphContent;    // like -isParagraphContent but then searches subtree if needed
- (void)removeNonParagraphContent;

- (DOMNode *)nodeByStrippingNonParagraphNodes:(SVParagraphHTMLContext *)context;

@end


#pragma mark -


@implementation SVParagraphHTMLContext

- (id)initWithParagraph:(SVBodyParagraph *)paragraph;
{
    OBPRECONDITION(paragraph);
    
    self = [self init];
    
    _paragraph = [paragraph retain];
    _unwrittenDOMElements = [[NSMutableArray alloc] init];
    
    return self;
}

- (void)dealloc
{
    [_paragraph release];
    [_unwrittenDOMElements release];
    
    [super dealloc];
}

@synthesize paragraph = _paragraph;

#pragma mark Writing

- (DOMNode *)writeDOMElement:(DOMElement *)element;
{
    // Remove any tags not allowed.
    DOMNode *replacement = [self replaceElementIfNeeded:element];
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

- (DOMNode *)replaceElementIfNeeded:(DOMElement *)element;
{
    DOMNode *result = element;
    NSString *tagName = [element tagName];
    
    
    // Remove any tags not allowed. Repeat cycle for the node that takes its place
    if (![[self class] isTagAllowed:tagName])
    {
        // Convert a bold or italic tag to <strong> or <em>
        if ([tagName isEqualToString:@"B"])
        {
            result = [self changeElement:element toTagName:@"STRONG"];
        }
        else if ([tagName isEqualToString:@"I"])
        {
            result = [self changeElement:element toTagName:@"EM"];
        }
        // Convert a <font> tag to <span> with appropriate styling
        else if ([tagName isEqualToString:@"FONT"])
        {
            result = [self changeElement:element toTagName:@"SPAN"];
            
            [self populateSpanElement:(DOMHTMLElement *)result
                      fromFontElement:(DOMHTMLFontElement *)element];
        }
        else
        {
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
            
            
            
            // Everything else gets removed, or replaced with a <span> with appropriate styling
            if ([[element style] length] > 0)
            {
                DOMElement *replacement = [self changeElement:element toTagName:@"SPAN"];
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

- (DOMElement *)changeElement:(DOMElement *)element toTagName:(NSString *)tagName;
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

- (void)populateSpanElement:(DOMElement *)span
            fromFontElement:(DOMHTMLFontElement *)fontElement;
{
    [[span style] setProperty:@"font-family" value:[fontElement face] priority:@""];
    [[span style] setProperty:@"color" value:[fontElement color] priority:@""];
    // Ignoring size for now, but may have to revisit
}

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
            [anElement openTagInContext:self];
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

+ (BOOL)isTagAllowed:(NSString *)tagName;
{
    BOOL result = ([tagName isEqualToString:@"A"] ||
                   [tagName isEqualToString:@"SPAN"] ||
                   [tagName isEqualToString:@"STRONG"] ||
                   [tagName isEqualToString:@"EM"] ||
                   [self isTagParagraphContent:tagName]);
    
    return result;
}

+ (BOOL)isTagParagraphContent:(NSString *)tagName;
{
    BOOL result = ([tagName isEqualToString:@"BR"]);
    
    return result;
}

@end


#pragma mark -


@implementation DOMNode (SVParagraphHTMLContext)

- (BOOL)isParagraphCharacterStyle; { return NO; }

- (void)flattenNodesAfterChild:(DOMNode *)aChild;
{
    // It doesn't make sense to flatten the *entire* contents of a node, so should always have a child to start from
    OBPRECONDITION(aChild);
    
    
    // Make a copy of ourself to flatten into
    DOMNode *clone = [self cloneNode:NO];
    
    
    // Flatten everything after aChild so it appears alongside ourself somewhere. Work backwards so order is maintained
    DOMNode *aNode;
    while ((aNode = [self lastChild]) && aNode != aChild)
    {
        [clone insertBefore:aNode refChild:[clone firstChild]];
    }
    
    
    // Place clone correctly
    if ([clone hasChildNodes])
    {
        [[self parentNode] insertBefore:clone refChild:[self nextSibling]];
    }
}

- (BOOL)isParagraphContent; { return NO; }

- (BOOL)hasParagraphContent;    // returns YES if the node or a descendant contains text, <br>, image etc.
{
    // Ask each child in turn
    if ([self isParagraphContent])
    {
        return YES;
    }
    else
    {
        for (DOMNode *aNode in [self mutableChildNodesArray])
        {
            if ([aNode hasParagraphContent]) return YES;
        }
    }
    
    return NO;
}

- (void)removeNonParagraphContent;
{
    DOMNode *aNode = [self firstChild];
    while (aNode)
    {
        DOMNode *nextNode = [aNode nextSibling];
        
        [aNode removeNonParagraphContent];
        if (![aNode hasChildNodes] && ![aNode isParagraphContent])
        {
            [self removeChild:aNode];
        }
        
        aNode = nextNode;
    }
}

- (DOMNode *)nodeByStrippingNonParagraphNodes:(SVParagraphHTMLContext *)context; { return self; }

@end

@implementation DOMElement (SVParagraphHTMLContext)

- (BOOL)isParagraphCharacterStyle; { return YES; }

- (BOOL)isParagraphContent;
{
    BOOL result = [SVParagraphHTMLContext isTagParagraphContent:[self tagName]];
    return result;
}

- (DOMNode *)nodeByStrippingNonParagraphNodes:(SVParagraphHTMLContext *)context;
{
    return [context replaceElementIfNeeded:self];
}

@end
        

@implementation DOMHTMLBRElement (SVParagraphHTMLContext)
- (BOOL)isParagraphCharacterStyle; { return NO; }
@end

@implementation DOMHTMLAnchorElement (SVParagraphHTMLContext)
- (BOOL)isParagraphCharacterStyle; { return NO; }
@end

@implementation DOMCharacterData (SVParagraphHTMLContext)
- (BOOL)isParagraphContent; { return YES; }
@end
