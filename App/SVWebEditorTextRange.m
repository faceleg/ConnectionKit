//
//  SVWebEditorTextRange.m
//  Sandvox
//
//  Created by Mike on 12/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVWebEditorTextRange.h"

#import "DOMNode+Karelia.h"


@interface DOMNode (SVWebEditorTextRange)
- (NSUInteger)SVWebEditorTextRange_length;
@end


#pragma mark -


@implementation SVWebEditorTextRange

- (id)initWithStartObject:(id)startObject index:(NSUInteger)startIndex
                endObject:(id)endObject index:(NSUInteger)endIndex;
{
    [self init];
    
    _startObject = [startObject retain];
    _startIndex = startIndex;
    _endObject = [endObject retain];
    _endIndex = endIndex;
    
    return self;
}

+ (NSUInteger)indexOfNode:(DOMNode *)startContainer fromNode:(DOMNode *)rootNode;
{
    DOMTreeWalker *treeWalker = [[rootNode ownerDocument]
                                 createTreeWalker:rootNode
                                 whatToShow:DOM_SHOW_ALL
                                 filter:nil
                                 expandEntityReferences:NO];
    
    NSUInteger result = 0;
    
    DOMNode *aNode = [treeWalker currentNode];
    while (aNode && aNode != startContainer)
    {
        result = result + [aNode SVWebEditorTextRange_length];
        aNode = [treeWalker nextNode];
    }
    
    return result;
}

+ (SVWebEditorTextRange *)rangeWithDOMRange:(DOMRange *)domRange
                               startElement:(DOMElement *)startElement
                                     object:(id)startObject
                                 endElement:(DOMElement *)endElement
                                     object:(id)endObject;
{
    // Seek out the start index
    DOMNode *startContainer = [domRange startContainer];
    NSUInteger startIndex = [self indexOfNode:startContainer fromNode:startElement];
    if ([startContainer nodeType] == DOM_TEXT_NODE) 
    {
        startIndex = startIndex + [domRange startOffset];
    }
    
    
    // Seek out end index
    DOMNode *endContainer = [domRange endContainer];
    NSUInteger endIndex = [self indexOfNode:endContainer fromNode:endElement];
    if ([endContainer nodeType] == DOM_TEXT_NODE)
    {
        endIndex = endIndex + [domRange endOffset];
    }
    
    
    // Build the result
    SVWebEditorTextRange *result = [[SVWebEditorTextRange alloc]
                                    initWithStartObject:startObject
                                    index:startIndex
                                    endObject:endObject
                                    index:endIndex];
    return [result autorelease];
}

- (void)dealloc
{
    [_startObject release];
    [_endObject release];
    
    [super dealloc];
}

@synthesize startObject = _startObject;
@synthesize startIndex = _startIndex;
@synthesize endObject = _endObject;
@synthesize endIndex = _endIndex;

- (void)populateDOMRange:(DOMRange *)range
        withStartElement:(DOMElement *)startElement
              endElement:(DOMElement *)endElement;
{
    BOOL foundStart = NO;
    
    
    // Locate the start of the range. OUCH
    DOMTreeWalker *treeWalker = [[startElement ownerDocument]
                                 createTreeWalker:startElement
                                 whatToShow:DOM_SHOW_ALL
                                 filter:nil
                                 expandEntityReferences:NO];
    
    DOMNode *aNode = [treeWalker currentNode];
    NSUInteger index = 0;
    while (aNode)
    {
        NSUInteger nodeLength = [aNode SVWebEditorTextRange_length];
        index = index + nodeLength;
        
        if (index > [self startIndex])
        {
            if (index - nodeLength == [self startIndex])
            {
                DOMNode *parentNode = [aNode parentNode];
                NSUInteger offset = [[parentNode mutableChildNodesArray] indexOfObjectIdenticalTo:aNode];
                [range setStart:parentNode offset:offset];
            }
            else
            {
                OBASSERT([aNode nodeType] == DOM_TEXT_NODE);
                NSUInteger offset = nodeLength - (index - [self startIndex]);
                [range setStart:aNode offset:offset];
            }
            
            foundStart = YES;
            break;
        }
        
        aNode = [treeWalker nextNode];
    }
    
    
    
    // Locate the end of the range
    treeWalker = [[endElement ownerDocument]
                  createTreeWalker:endElement
                  whatToShow:DOM_SHOW_ALL
                  filter:nil
                  expandEntityReferences:NO];
    
    aNode = [treeWalker currentNode];
    index = 0;
    while (aNode)
    {
        NSUInteger nodeLength = [aNode SVWebEditorTextRange_length];
        index = index + nodeLength;
        
        if (index >= [self endIndex])
        {
            if (index == [self endIndex])
            {
                DOMNode *parentNode = [aNode parentNode];
                NSUInteger offset = [[parentNode mutableChildNodesArray] indexOfObjectIdenticalTo:aNode];
                [range setEnd:parentNode offset:(offset + 1)];
            }
            else
            {
                OBASSERT([aNode nodeType] == DOM_TEXT_NODE);
                NSUInteger offset = nodeLength - (index - [self endIndex]);
                [range setEnd:aNode offset:offset];
            }
            
            // The start may not have been found; if so, fallback to matching the end
            if (!foundStart)
            {
                [range collapse:NO];
            }
            
            break;
        }
        
        aNode = [treeWalker nextNode];
    }
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    return [self retain];
}

@end


#pragma mark -


@implementation DOMNode (SVWebEditorTextRange)
- (NSUInteger)SVWebEditorTextRange_length; { return 0; }
@end


@implementation DOMText (SVWebEditorTextRange)
- (NSUInteger)SVWebEditorTextRange_length; { return [self length]; }
@end


