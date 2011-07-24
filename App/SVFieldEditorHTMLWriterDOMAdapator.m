//
//  SVFieldEditorHTMLWriterDOMAdapater.m
//  Sandvox
//
//  Created by Mike on 10/01/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVFieldEditorHTMLWriterDOMAdapator.h"

#import "NSIndexPath+Karelia.h"
#import "NSString+Karelia.h"

#import "DOMNode+Karelia.h"
#import "DOMElement+Karelia.h"
#import "DOMRange+Karelia.h"

#import "KSHTMLWriter.h"


@interface SVFieldEditorHTMLWriterDOMAdapator ()

- (DOMNode *)handleInvalidDOMElement:(DOMElement *)element;

- (DOMElement *)replaceDOMElement:(DOMElement *)element withElementWithTagName:(NSString *)tagName;
- (void)moveDOMElementToAfterParent:(DOMElement *)element;
- (DOMNode *)replaceDOMElementWithChildNodes:(DOMElement *)element;
- (void)populateSpanElementAttributes:(DOMElement *)span
                      fromFontElement:(DOMHTMLFontElement *)fontElement;

@end


#pragma mark -


@interface DOMNode (SVFieldEditorHTMLWriter)
- (void)flattenNodesAfterChild:(DOMNode *)aChild;

- (BOOL)isParagraphCharacterStyle;  // returns YES unless the receiver is text, <a>, <br>, image etc.

- (DOMNode *)nodeByStrippingNonParagraphNodes:(SVFieldEditorHTMLWriterDOMAdapator *)context;

@end


#pragma mark -


@implementation SVFieldEditorHTMLWriterDOMAdapator

- (id)initWithXMLWriter:(KSXMLWriter *)writer;
{
    return [self initWithOutputStringWriter:(id)writer];    // should blow up!
}

- (id)initWithOutputStringWriter:(KSStringWriter *)output;
{
    // All writing goes through a buffer first
    _output = [output retain];
    if (_output)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(outputWillFlush:)
                                                     name:KSStringWriterWillFlushNotification
                                                   object:_output];
    }
    
    KSHTMLWriter *writer = [[KSHTMLWriter alloc] initWithOutputWriter:_output];
    self = [super initWithXMLWriter:writer];
    [writer release];
    
    _attachments = [[NSMutableSet alloc] init];
    _pendingStartTagDOMElements = [[NSMutableArray alloc] init];
    _pendingEndDOMElements = [[NSMutableArray alloc] init];
    
    return self;
}

- (void)dealloc
{
    if (_output)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:KSStringWriterWillFlushNotification
                                                      object:_output];
        [_output release]; _output = nil;
    }
    
    [_attachments release];
    
    // [super dealloc] will call -flush at some point, so these ivars must be set to nil
    [_pendingStartTagDOMElements release]; _pendingStartTagDOMElements = nil;
    [_pendingEndDOMElements release]; _pendingEndDOMElements = nil;
    
    [super dealloc];
}

#pragma mark Properties

@synthesize importsGraphics = _allowsImages;
@synthesize allowsLinks = _allowsLinks;

#pragma mark Output

- (NSSet *)textAttachments; { return [[_attachments copy] autorelease]; }

- (void)writeTextAttachment:(SVTextAttachment *)attachment;
{
    [_attachments addObject:attachment];
    [[self XMLWriter] writeString:[NSString stringWithUnichar:NSAttachmentCharacter]];
}

#pragma mark Elements

- (DOMElement *)openDOMElementConflictingWithDOMElement:(DOMElement *)element
                                                tagName:(NSString *)tagName;
{
    NSArray *openElements = [[self XMLWriter] openElements];
    
    for (NSString *anElement in [openElements reverseObjectEnumerator])
    {
        if ([anElement isEqualToStringCaseInsensitive:tagName])
        {
            // Search for the DOM element in question
            DOMElement *result = (DOMElement *)[element parentNode];
            while (![[result tagName] isEqualToString:tagName])
            {
                result = (DOMElement *)[result parentNode];
            }
            
            return result;
        }
        
        // If there's a hyperlink open, don't want to search beyond that since the link could be split up
        if ([anElement isEqualToString:@"a"]) return nil;
    }
    
    return nil;
}

- (DOMNode *)willWriteDOMElement:(DOMElement *)element;
{
    DOMNode *result = [super willWriteDOMElement:element];
    
    if (result == element)
    {
        // Remove any tags not allowed. Repeat cycle for the node that takes its place
        NSString *tagName = [element tagName];
        if (![self validateElement:tagName])
        {
            return [self handleInvalidDOMElement:element];
        }
        
        
        // Build attributes earlier than superclass would so they get validated. Don't worry, won't get added twice as we check for that in -startElement:withDOMElement:
        [self buildAttributesForDOMElement:element element:[tagName lowercaseString]];
        
        
        // Remove attribute-less spans since they're basically worthless
        if ([tagName isEqualToString:@"SPAN"] && [[element attributes] length] == 0)
        {
            return [self replaceDOMElementWithChildNodes:element];
        }
        
        
        
        // Are we about to open an inline element which matches the one just written? If so, merge them into one. This is made possible by not yet having written the end tag of the element.
        DOMElement *elementToMergeInto = [_pendingEndDOMElements lastObject];
        
        if ([elementToMergeInto parentNode] == [element parentNode] &&  // must be siblings or bad stuff happens
            [elementToMergeInto isEqualNode:element compareChildNodes:NO])
        {
            // Dispose of markup: previous end tag, and this start tag
            [_output cancelFlushOnNextWrite];
            [_output beginBuffering];
            
            [super startElement:[tagName lowercaseString] withDOMElement:element];
            [_pendingEndDOMElements removeLastObject];
            
            [_output discardBuffer];
            
            
            // Write inner HTML
            [self writeInnerOfDOMNode:element];
            
            
            // Do the merge in the DOM
            [[elementToMergeInto mutableChildDOMNodes] addObjectsFromArray:[element mutableChildDOMNodes]];
            [[element parentNode] removeChild:element];
            
            
            // Carry on. We know the element can't be deemed content in its own right since was checked in previous iteration
            return [self endElementWithDOMElement:elementToMergeInto];
        }
        
        
        
        // Generally, can't allow nested elements.
        // e.g. <span><span>foo</span> bar</span>   is wrong and should be simplified.
        // Nested lists are fine though
        if (![tagName isEqualToString:@"OL"] && ![tagName isEqualToString:@"UL"])
        {
            // The other exception is if outer element has font: property, and inner element overrides that using longhand. e.g. font-family
            // Under those circumstances, WebKit doesn't give us enough API to make the merge, so keep both elements.
            // #100362
            DOMElement *existingElement = [self openDOMElementConflictingWithDOMElement:element
                                                                                tagName:tagName];
            if (existingElement)
            {
                // Is it really a conflict?
                if ([element tryToPopulateStyleWithValuesInheritedFromElement:existingElement])
                {
                    // Shuffle up following nodes
                    DOMNode *parent = [element parentNode];
                    [parent flattenNodesAfterChild:element];
                    
                    
                    // Try to flatten the conflict
                    // It make take several moves up the tree till we find the conflicting element
                    while (parent != existingElement)
                    {
                        // Move element across to a clone of its parent
                        DOMNode *clone = [parent cloneNode:NO];
                        [[parent parentNode] insertBefore:clone refChild:[parent nextSibling]];
                        [clone appendChild:element];
                        parent = [parent parentNode];
                    }
                    
                    
                    // Pretend we wrote the element and are now finished. Recursion will take us back to the element in its new location to write it for real
                    [self moveDOMElementToAfterParent:element];
                    result = nil;
                }
            }
        }
    }
        
        
    return result;
}

// Elements used for styling are worthless if they have no content of their own. We treat them specially by buffering internally until some actual content gets written. If there is none, go ahead and delete the element instead. Shouldn't need to call this directly; -writeDOMElement: does so internally.
- (void)startElement:(NSString *)elementName withDOMElement:(DOMElement *)element;    // open the tag and write attributes
{
    BOOL isStyling = ![[self class] isElementWithTagNameContent:elementName];
    if (isStyling)
    {
        // ..so push onto the stack, ready to write if requested. But only if it's not to be merged with the previous element
        [_output cancelFlushOnNextWrite];   // as we're about to write into the buffer
        [_pendingStartTagDOMElements addObject:element];
        [_output beginBuffering];
    }
    
    
    // If attributes haven't already been built, now is the time to do so
    if (![[self XMLWriter] currentElementHasAttributes])
    {
        [self buildAttributesForDOMElement:element element:elementName];
    }
    
    
    // Open tag. Make it inline so we match DOM exactly. (i.e text nodes take care of whitespace for us)
    [[self XMLWriter] startElement:elementName writeInline:YES];
    
    
    // Finish setting up buffer
    if (isStyling) [_output flushOnNextWrite];
}

- (DOMNode *)endElementWithDOMElement:(DOMElement *)element;
{
    DOMNode *result = nil;
    
    NSString *tagName = [[self XMLWriter] topElement];
    if ([[self class] isElementWithTagNameContent:tagName])
    {
        result = [super endElementWithDOMElement:element];
    }
    else
    {
        // If there was no actual content inside the element, then it should be thrown away. We can tell this by examining the stack
        if ([_pendingStartTagDOMElements lastObject] == element)
        {
            [_output cancelFlushOnNextWrite];   // resume buffering so the end tag doesn't get written
            
            result = [super endElementWithDOMElement:element];
            
            [[element parentNode] removeChild:element];
            [_pendingStartTagDOMElements removeLastObject];
            
            [_output flushOnNextWrite];
            [_output discardBuffer];    // will cancel -flushOnNextWrite if that was the last buffer
        }
        else
        {
            if ([tagName isEqualToStringCaseInsensitive:@"P"])
            {
                result = [super endElementWithDOMElement:element];
            }
            else
            {
                // Close the element, but wait and see if the next sibling is equal & therefore to be merged
                [_output beginBuffering];
                result = [super endElementWithDOMElement:element];
                [_output flushOnNextWrite];
                
                [_pendingEndDOMElements addObject:element];
            }
        }
    }
    
    return result;
}

#pragma mark Cleanup

- (DOMNode *)handleInvalidDOMElement:(DOMElement *)element;
{
    DOMNode *result;    // not setting the result is a programmer error
    NSString *tagName = [element tagName];
    
    
    // Convert a bold or heading tag to <STRONG>
    if ([tagName isEqualToString:@"B"] ||
        [element isKindOfClass:[DOMHTMLHeadingElement class]])
    {
        result = [self replaceDOMElement:element withElementWithTagName:@"STRONG"];
    }
    
    // Convert italics to <EM>
    else if ([tagName isEqualToString:@"I"])
    {
        result = [self replaceDOMElement:element withElementWithTagName:@"EM"];
    }
    
    // Convert <TT> to <CODE>
    else if ([tagName isEqualToString:@"TT"])
    {
        result = [self replaceDOMElement:element withElementWithTagName:@"CODE"];
    }
    
    // Convert a <FONT> tag to <SPAN> with appropriate styling
    else if ([tagName isEqualToString:@"FONT"])
    {
        result = [self replaceDOMElement:element withElementWithTagName:@"SPAN"];
        
        [self populateSpanElementAttributes:(DOMHTMLElement *)result
                  fromFontElement:(DOMHTMLFontElement *)element];
    }
    else
    {
        // Everything else gets removed, or replaced with a <span> with appropriate styling
        if ([[element style] length] > 0)
        {
            DOMElement *replacement = [self replaceDOMElement:element withElementWithTagName:@"SPAN"];
            [replacement tryToPopulateStyleWithValuesInheritedFromElement:element];
            
            result = replacement;
        }
        else
        {
            result = [self replaceDOMElementWithChildNodes:element];
        }
        
        
        
    }
    
    return [result nodeByStrippingNonParagraphNodes:self];
}

#pragma mark Modifying the DOM

- (DOMElement *)replaceDOMElement:(DOMElement *)element withElementWithTagName:(NSString *)tagName;
{
    // When editing the DOM, WebKit has a nasty habbit of losing track of the selection. Since we're swapping one node for another, can correct by deducing new selection from index paths.
    // We probably don't actually need to do this for all changes, only those inside the selection, but then, maybe that's where all changes should be happening anyway?
    DOMDocument *doc = [element ownerDocument];
    WebView *webView = [[doc webFrame] webView];
    DOMRange *selection = [webView selectedDOMRange];
    
    NSIndexPath *startPath = [selection ks_startIndexPathFromNode:doc];
    NSIndexPath *endPath = [selection ks_endIndexPathFromNode:doc];
    
    // Make replacement
    DOMElement *result = [[element parentNode] replaceChildNode:element
                                      withElementWithTagName:tagName
                                                moveChildren:YES];
    
    
    // Try to correct selection
    if (startPath) [selection ks_setStartWithIndexPath:startPath fromNode:doc];
    if (endPath) [selection ks_setEndWithIndexPath:endPath fromNode:doc];
    
    [webView setSelectedDOMRange:selection affinity:[webView selectionAffinity]];
    
    
    return result;
}

- (void)moveDOMElementToAfterParent:(DOMElement *)element;
{
    OBPRECONDITION(element);
    /*  Support method that makes the move, and maintains selection when possible
     */
    
    
    // Get hold of selection to see if it will be affected
    WebView *webView = [[[element ownerDocument] webFrame] webView];
    DOMRange *selection = [webView selectedDOMRange];
    NSSelectionAffinity affinity = [webView selectionAffinity];
    
    NSIndexPath *startPath = [selection ks_startIndexPathFromNode:element];
    NSIndexPath *endPath = [selection ks_endIndexPathFromNode:element];
    
    // Make the move
    DOMNode *parent = [element parentNode];
    [[parent parentNode] insertBefore:element refChild:[parent nextSibling]];
    
    // Repair the selection as needed
    if (startPath) [selection ks_setStartWithIndexPath:startPath fromNode:element];
    if (endPath) [selection ks_setEndWithIndexPath:endPath fromNode:element];
    
    if (startPath || endPath)
    {
        [webView setSelectedDOMRange:selection affinity:affinity];
    }
}

- (DOMNode *)replaceDOMElementWithChildNodes:(DOMElement *)element
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

- (void)populateSpanElementAttributes:(DOMElement *)span
                      fromFontElement:(DOMHTMLFontElement *)fontElement;
{
    [[span style] setProperty:@"font-family" value:[fontElement face] priority:@""];
    [[span style] setProperty:@"color" value:[fontElement color] priority:@""];
    // Ignoring size for now, but may have to revisit
}

#pragma mark High-level Writing

// Comments have no place in text fields!
- (DOMNode *)writeComment:(NSString *)comment withDOMComment:(DOMComment *)commentNode;
{
    DOMNode *result = [commentNode nextSibling];
    [[commentNode parentNode] removeChild:commentNode];
    return result;
}

- (DOMNode *)didWriteDOMText:(DOMText *)textNode nextNode:(DOMNode *)nextNode;
{
    // Is the next node also text? If so, normalize by appending to textNode. #68577
    if ([nextNode nodeType] == DOM_TEXT_NODE)
    {
        // Do usual writing. Produces correct output, and handles possibility of a chain of unnormalized text nodes
        DOMNode *nodeToAppend = nextNode;
        nextNode = [nodeToAppend performSelector:@selector(ks_writeHTML:) withObject:self];
        
        
        // Maintain selection
        WebView *webView = [[[textNode ownerDocument] webFrame] webView];
        DOMRange *selection = [webView selectedDOMRange];
        NSSelectionAffinity affinity = [webView selectionAffinity];
        
        NSUInteger length = [textNode length];
        NSIndexPath *startPath = [[selection ks_startIndexPathFromNode:nodeToAppend] indexPathByAddingToLastIndex:length];
        NSIndexPath *endPath = [[selection ks_endIndexPathFromNode:nodeToAppend] indexPathByAddingToLastIndex:length];
        
        
        // Delete node by appending to ourself
        [textNode appendData:[nodeToAppend nodeValue]];
        [[nodeToAppend parentNode] removeChild:nodeToAppend];
        
        
        // Restore selection
        if (startPath) [selection ks_setStartWithIndexPath:startPath fromNode:textNode];
        if (endPath) [selection ks_setEndWithIndexPath:endPath fromNode:textNode];
        if (startPath || endPath) [webView setSelectedDOMRange:selection affinity:affinity];
    }
    
    return [super didWriteDOMText:textNode nextNode:nextNode];
}

#pragma mark Tag Whitelist

- (BOOL)validateElement:(NSString *)tagName;
{
    BOOL result = [[self class] validateElement:tagName];
    
    if (![self allowsLinks] && [tagName isEqualToString:@"A"]) result = NO;
    
    // List items are permitted inside of a list. We don't actually allow lists, but this is handy for subclasses that do implement lists
    if (!result && [tagName isEqualToString:@"LI"])
    {
        if ([(KSHTMLWriter *)[self XMLWriter] topElementIsList]) result = YES;
    }
    
    return result;
}

+ (BOOL)validateElement:(NSString *)tagName;    // can this sort of element ever be valid?
{
    BOOL result = ([tagName isEqualToString:@"SPAN"] ||
                   [tagName isEqualToString:@"STRONG"] ||
                   [tagName isEqualToString:@"EM"] ||
                   [tagName isEqualToString:@"CODE"] ||
                   [tagName isEqualToString:@"BR"] ||
                   [tagName isEqualToString:@"SUP"] ||
                   [tagName isEqualToString:@"SUB"] ||
                   [tagName isEqualToString:@"A"] ||
                   [tagName isEqualToString:@"U"]);
    
    return result;
}

+ (BOOL)isElementWithTagNameContent:(NSString *)tagName;
{
    // Used to report <P> elements as content. Don't actually want to since an empty <P> element should be removed
    BOOL result = ([tagName isEqualToStringCaseInsensitive:@"BR"] || [tagName isEqualToStringCaseInsensitive:@"LI"]);
    
    return result;
}

#pragma mark Attributes

- (NSString *)validateAttribute:(NSString *)attributeName
                          value:(NSString *)value
                      ofElement:(NSString *)elementName;
{
    if ([elementName isEqualToString:@"a"])
    {
        if ([attributeName isEqualToString:@"href"] ||
            [attributeName isEqualToString:@"target"] ||
            [attributeName isEqualToString:@"style"] ||
            [attributeName isEqualToString:@"charset"] ||
            [attributeName isEqualToString:@"hreflang"] ||
            [attributeName isEqualToString:@"name"] ||
            [attributeName isEqualToString:@"title"] ||
            [attributeName isEqualToString:@"rel"] ||
            [attributeName isEqualToString:@"rev"])
        {
            return value;
        }
    }
    // <FONT> tags are no longer allowed, but leave this in in case we turn support back on again
    else if ([elementName isEqualToString:@"font"])
    {
        if ([attributeName isEqualToString:@"face"] || [attributeName isEqualToString:@"size"] || [attributeName isEqualToString:@"color"]) return value;
    }
    
    // Allow style on any element except <BR>.
    // Used to allow class. #94455
    if ([elementName isEqualToString:@"br"])
    {
        if ([attributeName isEqualToString:@"style"]) value = nil;
    }
    
    // Dissallow "in" & "Apple-style-span" classes as are unwanted
    if ([attributeName isEqualToString:@"class"])
    {
        NSMutableArray *components = [[value componentsSeparatedByWhitespace] mutableCopy];
        [components removeObject:@"in"];
        [components removeObject:@"Apple-style-span"];
        
        value = [components componentsJoinedByString:@" "];
        [components release];
    }
    
    // Strip empty style attributes
    if ([value length] == 0 &&
        ([attributeName isEqualToString:@"style"] || [attributeName isEqualToString:@"class"]))
    {
        value = nil;
    }
    
    return value;
}

- (void)buildAttributesForDOMElement:(DOMElement *)element element:(NSString *)elementName
{
    // Write attributes
    if ([element hasAttributes]) // -[DOMElement attributes] is slow as it has to allocate an object. #78691
    {
        DOMNamedNodeMap *attributes = [element attributes];
        NSUInteger index;
        for (index = 0; index < [attributes length]; index++)
        {
            // Check each attribute should be written
            DOMAttr *anAttribute = (DOMAttr *)[attributes item:index];
            NSString *attributeName = [anAttribute name];
            NSString *attributeValue = [anAttribute value];
            
            if (attributeValue = [self validateAttribute:attributeName value:attributeValue ofElement:elementName])
            {
                // Validate individual styling
                if ([attributeName isEqualToString:@"style"])
                {
                    DOMCSSStyleDeclaration *style = [element style];
                    [self removeUnsupportedCustomStyling:style fromElement:elementName];
                    
                    // Have to write it specially as changes don't show up in [anAttribute value] sadly
                    [[self XMLWriter] pushAttribute:@"style" value:[style cssText]];
                }
                else
                {
                    [[self XMLWriter] pushAttribute:attributeName value:attributeValue];
                }
            }
            else
            {
                [attributes removeNamedItem:attributeName];
                index--;
            }
        }
    }
}

#pragma mark Styling Whitelist

- (BOOL)validateStyleProperty:(NSString *)propertyName ofElementWithTagName:(NSString *)tagName;
{
    BOOL result = ([propertyName isEqualToString:@"font"] ||
                   [propertyName hasPrefix:@"font-"] ||
                   [propertyName isEqualToString:@"color"] ||
                   [propertyName isEqualToString:@"background-color"] ||
                   [propertyName isEqualToString:@"text-decoration"] ||
                   [propertyName isEqualToString:@"text-shadow"]);
    
    return result;
}

- (void)removeUnsupportedCustomStyling:(DOMCSSStyleDeclaration *)style
                fromElement:(NSString *)tagName;
{
    for (int i = [style length]; i > 0;)
    {
        i--;
        NSString *name = [style item:i];
        if (![self validateStyleProperty:name ofElementWithTagName:tagName]) [style removeProperty:name];
    }
}

#pragma mark Buffering

- (void)outputWillFlush:(NSNotification *)notification;
{
    // Before actually writing the string, push through any pending Elements.
    [_pendingStartTagDOMElements removeAllObjects];
    [_pendingEndDOMElements removeAllObjects];
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

- (DOMNode *)nodeByStrippingNonParagraphNodes:(SVFieldEditorHTMLWriterDOMAdapator *)context; { return self; }

@end

@implementation DOMElement (SVFieldEditorHTMLWriter)

- (BOOL)isParagraphCharacterStyle; { return YES; }

- (DOMNode *)nodeByStrippingNonParagraphNodes:(SVFieldEditorHTMLWriterDOMAdapator *)adaptor;
{
    if (![adaptor validateElement:[self tagName]])
    {
        return [adaptor handleInvalidDOMElement:self];
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
