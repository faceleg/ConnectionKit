//
//  SVWebEditorTextRange.m
//  Sandvox
//
//  Created by Mike on 12/02/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVWebEditorTextRange.h"

#import "DOMRange+Karelia.h"

#import "DOMNode+Karelia.h"


@interface DOMNode (SVWebEditorTextRange)
- (NSUInteger)SVWebEditorTextRange_length;
@end


#pragma mark -


@implementation SVWebEditorTextRange

- (id)initWithContainerObject:(id)container
               startIndexPath:(NSIndexPath *)startPath
                 endIndexPath:(NSIndexPath *)endPath;
{
    OBPRECONDITION(container);
    OBPRECONDITION(startPath);
    OBPRECONDITION(endPath);
    
    [super init];
    
    _containerObject = [container retain];
    _startIndexPath = [startPath copy];
    _endIndexPath = [endPath copy];
    
    return self;
}

- (id)init;
{
    return [self initWithContainerObject:nil startIndexPath:nil endIndexPath:nil];
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
                            containerObject:(id)containerObject
                              containerNode:(DOMNode *)containerNode;
{
    // Seek out the start index
    NSIndexPath *startPath = [domRange ks_startIndexPathFromNode:containerNode];
    
    
    // Seek out end index
    NSIndexPath *endPath = [domRange ks_endIndexPathFromNode:containerNode];
    
    
    // Build the result
    SVWebEditorTextRange *result = [[SVWebEditorTextRange alloc]
                                    initWithContainerObject:containerObject
                                    startIndexPath:startPath
                                    endIndexPath:endPath];
    
    return [result autorelease];
}

- (void)dealloc
{
    [_containerObject release];
    [_startIndexPath release];
    [_endIndexPath release];

    [super dealloc];
}

@synthesize containerObject = _containerObject;
@synthesize startIndexPath = _startIndexPath;
@synthesize endIndexPath = _endIndexPath;

- (void)populateDOMRange:(DOMRange *)range fromContainerNode:(DOMNode *)commonAncestorContainer;
{
    // Locate the start of the range. OUCH
    [range ks_setStartWithIndexPath:[self startIndexPath] fromNode:commonAncestorContainer];
    
    
    
    // Locate the end of the range
    [range ks_setEndWithIndexPath:[self endIndexPath] fromNode:commonAncestorContainer];
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


