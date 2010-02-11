//
//  SVHTMLContext+DOM.m
//  Sandvox
//
//  Created by Mike on 11/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//


#import "SVHTMLContext.h"

#import "NSString+Karelia.h"


static NSSet *sTagsWithNewlineOnOpen = nil;
static NSSet *sTagsThatCanBeSelfClosed = nil;
static NSSet *sTagsWithNewlineOnClose = nil;


@implementation SVHTMLContext (DOM)

- (DOMNode *)writeDOMElement:(DOMElement *)element;
{
    // Open tag
    [self openTagWithDOMElement:element];
    
    // Close tag
    [self closeStartTag];
    
    // Write contents
    [element writeInnerHTMLToContext:self];
    
    // Write end tag
    [self writeEndTag];
    
    
    return [element nextSibling];
}

- (void)openTagWithDOMElement:(DOMElement *)element;    // open the tag and write attributes
{
    // Open tag
    [self openTag:[[element tagName] lowercaseString]];
    
    // Write attributes
    DOMNamedNodeMap *attributes = [element attributes];
    NSUInteger index;
    for (index = 0; index < [attributes length]; index++)
    {
        DOMAttr *anAttribute = (DOMAttr *)[attributes item:index];
        [self writeAttribute:[anAttribute name] value:[anAttribute value]];
    }
}

@end


#pragma mark -


@interface DOMNode (SVHTMLContext)

// All nodes can be written to a context. DOMElement overrides the standard behaviour to call -[SVHTMLContext writeDOMElement:]
//  From there, writing recurses down through the element's children.
- (DOMNode *)writeHTMLToContext:(SVHTMLContext *)context;

@end


#pragma mark -


@implementation DOMNode (SVHTMLContext)

- (DOMNode *)writeHTMLToContext:(SVHTMLContext *)context;
{
    [context writeText:[self nodeValue]];
    return [self nextSibling];
} 

@end


#pragma mark -


@implementation DOMElement (SVHTMLContext)

- (DOMNode *)writeHTMLToContext:(SVHTMLContext *)context;
{
    //  *Elements* are where the clever recursion starts, so switch responsibility back to the context.
    return [context writeDOMElement:self];
}

- (void)writeInnerHTMLToContext:(SVHTMLContext *)context
{
    [self writeInnerHTMLStartingWithNode:nil toContext:context];
}

- (void)writeInnerHTMLStartingWithNode:(DOMNode *)aNode toContext:(SVHTMLContext *)context;
{
    // It's best to iterate using a Linked List-like approach in case the iteration also modifies the DOM
    if (!aNode) aNode = [self firstChild];
    
    while (aNode)
    {
        aNode = [aNode writeHTMLToContext:context];
    }
}

- (void)writeCleanedHTMLToContext:(SVHTMLContext *)context innards:(BOOL)writeInnards;
{
	[context openTagWithDOMElement:self];
    
	
	if (!sTagsThatCanBeSelfClosed)
	{
		sTagsThatCanBeSelfClosed = [[NSSet alloc] initWithObjects:@"img", @"br", @"hr", @"p", @"meta", @"link", @"base", @"param", nil];
	}
	
    
    NSString *tagName = [[self tagName] lowercaseString];
    
	if ([self hasChildNodes] || ![sTagsThatCanBeSelfClosed containsObject:tagName])
	{
		[context closeStartTag];		// close the node first
		
		if (nil == sTagsWithNewlineOnOpen)
		{
			sTagsWithNewlineOnOpen = [[NSSet alloc] initWithObjects:@"head", @"body", @"ul", @"ol", @"table", @"tr", nil];
		}
		if ([sTagsWithNewlineOnOpen containsObject:tagName])
		{
			[context writeNewline];
		}
		if (writeInnards)
		{
			if ([self hasChildNodes])
			{
				[self writeCleanedInnerHTMLToContext:context];		// <----- RECURSION POINT
			}
			[context writeEndTag];
		}
	}
	else	// no children, self-close tag.
	{
		[context closeEmptyElementTag];
	}
	
	if (writeInnards)	// only deal with newline if we're doing the innards too
	{
		if (!sTagsWithNewlineOnClose)
		{
			sTagsWithNewlineOnClose = [[NSSet alloc] initWithObjects:@"ul", @"ol", @"table", @"li", @"p", @"h1", @"h2", @"h3", @"h4", @"blockquote", @"br", @"pre", @"td", @"tr", @"div", @"hr", nil];
		}
		if ([sTagsWithNewlineOnClose containsObject:tagName])
		{
			[context writeNewline];
		}
	}
}

@end


#pragma mark -


@implementation DOMComment (SVHTMLContext)

- (DOMNode *)writeHTMLToContext:(SVHTMLContext *)context;
{
	[context writeComment:[self data]];
    return [self nextSibling];
}

@end


#pragma mark -


@implementation DOMCDATASection (SVHTMLContext)

- (DOMNode *)writeHTMLToContext:(SVHTMLContext *)context;
{
	[context writeHTMLString:[NSString stringWithFormat:@"<![CDATA[%@]]>", [self data]]];
    return [self nextSibling];
}

@end


