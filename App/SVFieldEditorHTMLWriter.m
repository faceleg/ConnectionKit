//
//  SVFieldEditorHTMLWriter.m
//  Sandvox
//
//  Created by Mike on 10/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVFieldEditorHTMLWriter.h"

#import "DOMNode+Karelia.h"
#import "DOMElement+Karelia.h"


@interface SVFieldEditorHTMLWriter ()

- (DOMNode *)handleInvalidDOMElement:(DOMElement *)element;

- (DOMElement *)changeDOMElement:(DOMElement *)element toTagName:(NSString *)tagName;
- (DOMNode *)unlinkDOMElementBeforeWriting:(DOMElement *)element;
- (void)populateSpanElementAttributes:(DOMElement *)span
                      fromFontElement:(DOMHTMLFontElement *)fontElement;

@end


#pragma mark -


@interface DOMNode (SVFieldEditorHTMLWriter)
- (void)flattenNodesAfterChild:(DOMNode *)aChild;

- (BOOL)isParagraphCharacterStyle;  // returns YES unless the receiver is text, <a>, <br>, image etc.

- (BOOL)isParagraphContent;     // returns YES if the receiver is text, <br>, image etc.

- (DOMNode *)nodeByStrippingNonParagraphNodes:(SVFieldEditorHTMLWriter *)context;

@end


#pragma mark -


@implementation SVFieldEditorHTMLWriter

- (id)initWithStringWriter:(id <KSStringWriter>)stream
{
    self = [super initWithStringWriter:stream];
    
    _pendingStartTagDOMElements = [[NSMutableArray alloc] init];
    _pendingEndDOMElements = [[NSMutableArray alloc] init];
    
    return self;
}

- (void)dealloc
{
    // [super dealloc] will call -flush at some point, so these ivars must be set to nil
    [_pendingStartTagDOMElements release]; _pendingStartTagDOMElements = nil;
    [_pendingEndDOMElements release]; _pendingEndDOMElements = nil;
    
    [super dealloc];
}

#pragma mark Elements

- (DOMNode *)_writeDOMElement:(DOMElement *)element;
{
    // Remove any tags not allowed. Repeat cycle for the node that takes its place
    NSString *tagName = [element tagName];
    if (![self validateTagName:tagName])
    {
        return [self handleInvalidDOMElement:element];
    }
    
    
    
    // Are we about to open an inline element which matches the one just written? If so, merge them into one. This is made possible by not yet having written the end tag of the element.
    DOMElement *elementToMergeInto = [_pendingEndDOMElements lastObject];
    if ([elementToMergeInto isEqualNode:element compareChildNodes:NO])
    {
        [_pendingEndDOMElements removeLastObject];
        [self discardBuffer];
        [self pushOpenElementWithTagName:[element tagName]];
        
        
        // Write inner HTML
        [self writeInnerOfDOMNode:element];
        
        
        // Do the merge in the DOM
        [[elementToMergeInto mutableChildDOMNodes] addObjectsFromArray:[element mutableChildDOMNodes]];
        [[element parentNode] removeChild:element];
        
        
        // Carry on. We know the element can't be deemed content in its own right since was checked in previous iteration
        return [self endStylingDOMElement:elementToMergeInto];
    }
    
    
    
    // Can't allow nested elements. e.g.    <span><span>foo</span> bar</span>   is wrong and should be simplified.
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
        return [super _writeDOMElement:element];
    }
    else
    {
        return [self writeStylingDOMElement:element];
    }
}

- (DOMNode *)writeStylingDOMElement:(DOMElement *)element;
{
    // ..so push onto the stack, ready to write if requested. But only if it's not to be merged with the previous element
    [_pendingStartTagDOMElements addObject:element];
    [self beginBuffering];
    
    // Open tag
    [self openTagWithDOMElement:element];
    
    // Close tag
    [self closeStartTag];
    
    [self flushOnNextWrite];
    
    
    // Write inner HTML
    [self writeInnerOfDOMNode:element];
    
    
    // Write end tag
    return [self endStylingDOMElement:element];
}

- (DOMNode *)endStylingDOMElement:(DOMElement *)element;
{
    // If there was no actual content inside the element, then it should be thrown away. We can tell this by examining the stack
    if ([_pendingStartTagDOMElements lastObject] == element)
    {
        // I'm not 100% sure this works with the new buffering code yet.
        DOMNode *result = [element nextSibling];
        
        [[element parentNode] removeChild:element];
        [self popOpenElement];
        [_pendingStartTagDOMElements removeLastObject];
        
        [self discardBuffer];
        
        return result;
    }
    else
    {
        if ([[element tagName] isEqualToString:@"P"])
        {
            [self writeEndTag];
        }
        else
        {
            // Close the element, but wait and see if the next sibling is equal & therefore to be merged
            [self beginBuffering];
            [self writeEndTag];
            [self flushOnNextWrite];
            
            [_pendingEndDOMElements addObject:element];
        }
        
        return [element nextSibling];
    }
}

#pragma mark Cleanup

- (DOMNode *)handleInvalidDOMElement:(DOMElement *)element;
{
    DOMNode *result;    // not setting the result is a programmer error
    NSString *tagName = [element tagName];
    
    
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
    
    return [result nodeByStrippingNonParagraphNodes:self];
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
                DOMCSSStyleDeclaration *style = [element style];
                [self removeUnsupportedCustomStyling:style];
                
                // Have to write it specially as changes don't show up in [anAttribute value] sadly
                [self writeAttribute:@"style" value:[style cssText]];
            }
            else
            {
                [self writeAttribute:attributeName value:[anAttribute value]];
            }
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

- (DOMNode *)didWriteDOMText:(DOMText *)textNode nextNode:(DOMNode *)nextNode;
{
    // Is the next node also text? If so, normalize by appending to textNode. #68577
    if ([nextNode nodeType] == DOM_TEXT_NODE)
    {
        // Do usual writing. Produces correct output, and handles possibility of a chain of unnormalized text nodes
        DOMNode *nodeToAppend = nextNode;
        nextNode = [nodeToAppend performSelector:@selector(writeHTMLToContext:) withObject:self];
        
        // Delete node by appending to ourself
        [textNode appendData:[nodeToAppend nodeValue]];
        [[nodeToAppend parentNode] removeChild:nodeToAppend];
    }
    
    return [super didWriteDOMText:textNode nextNode:nextNode];
}

#pragma mark Tag Whitelist

- (BOOL)validateTagName:(NSString *)tagName;
{
    BOOL result = ([tagName isEqualToString:@"SPAN"] ||
                   [tagName isEqualToString:@"STRONG"] ||
                   [tagName isEqualToString:@"EM"] ||
                   [[self class] isElementWithTagNameContent:tagName] ||
                   [tagName isEqualToString:@"P"] ||    // used to be covered by -isElementWithTagNameContent:
                   [tagName isEqualToString:@"SUP"] ||
                   [tagName isEqualToString:@"SUB"]);
    
    // List items are permitted inside of a list. We don't actually allow lists, but this is handy for subclasses that do implement lists
    if (!result && [tagName isEqualToString:@"LI"])
    {
        if ([self lastOpenElementIsList]) result = YES;
    }
    
    return result;
}

+ (BOOL)isElementWithTagNameContent:(NSString *)tagName;
{
    // Used to report <P> elements as content. Don't actually want to since an empty <P> element should be removed
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

#pragma mark Buffering

- (void)flush;
{
    // Before actually writing the string, push through any pending Elements.
    [_pendingStartTagDOMElements removeAllObjects];
    [_pendingEndDOMElements removeAllObjects];
    
    
    
    
    [super flush];
}

@end


#pragma mark -


@implementation DOMNode (SVFieldEditorHTMLWriter)

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

- (DOMNode *)nodeByStrippingNonParagraphNodes:(SVFieldEditorHTMLWriter *)context; { return self; }

@end

@implementation DOMElement (SVFieldEditorHTMLWriter)

- (BOOL)isParagraphCharacterStyle; { return YES; }

- (BOOL)isParagraphContent;
{
    BOOL result = [SVFieldEditorHTMLWriter isElementWithTagNameContent:[self tagName]];
    return result;
}

- (DOMNode *)nodeByStrippingNonParagraphNodes:(SVFieldEditorHTMLWriter *)context;
{
    if (![context validateTagName:[self tagName]])
    {
        return [context handleInvalidDOMElement:self];
    }
    
    return self;
}

@end
        

@implementation DOMHTMLBRElement (SVFieldEditorHTMLWriter)
- (BOOL)isParagraphCharacterStyle; { return NO; }
@end

@implementation DOMHTMLAnchorElement (SVFieldEditorHTMLWriter)
- (BOOL)isParagraphCharacterStyle; { return NO; }
@end

@implementation DOMCharacterData (SVFieldEditorHTMLWriter)
- (BOOL)isParagraphContent; { return YES; }
@end
