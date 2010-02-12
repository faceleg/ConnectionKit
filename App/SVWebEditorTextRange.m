//
//  SVWebEditorTextRange.m
//  Sandvox
//
//  Created by Mike on 12/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVWebEditorTextRange.h"


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

@end


#pragma mark -


@implementation DOMNode (SVWebEditorTextRange)
- (NSUInteger)SVWebEditorTextRange_length; { return 0; }
@end


@implementation DOMText (SVWebEditorTextRange)
- (NSUInteger)SVWebEditorTextRange_length; { return [self length]; }
@end


