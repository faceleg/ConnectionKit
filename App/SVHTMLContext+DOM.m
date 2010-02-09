//
//  SVHTMLContext+DOM.m
//  Sandvox
//
//  Created by Mike on 11/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//


#import "SVHTMLContext.h"

#import "NSString+Karelia.h"


static NSSet *sTagsWithNewlineOnOpen  = nil;
static NSSet *sTagsThatCanBeSelfClosed  = nil;
static NSSet *sTagsWithNewlineOnClose = nil;


@implementation SVHTMLContext (DOM)

- (DOMNode *)writeDOMElement:(DOMElement *)element;
{
    // Open tag
    [element openTagInContext:self];
    
    // Close tag
    [self closeStartTag];
    
    // Write contents
    [element writeInnerHTMLToContext:self];
    
    // Write end tag
    [self writeEndTag];
    
    
    return [element nextSibling];
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

- (void)openTagInContext:(SVHTMLContext *)context;
{
    // Open tag
    [context openTag:[[self tagName] lowercaseString]];
    
    // Write attributes
    DOMNamedNodeMap *attributes = [self attributes];
    NSUInteger index;
    for (index = 0; index < [attributes length]; index++)
    {
        DOMAttr *anAttribute = (DOMAttr *)[attributes item:index];
        [context writeAttribute:[anAttribute name] value:[anAttribute value]];
    }
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
	[self openTagInContext:context];
    
	
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


@implementation DOMText (SVHTMLContext)

- (DOMNode *)writeHTMLToContext:(SVHTMLContext *)context;
{
	NSString *text = [self data];
	
	// Hack -- instead of escaping the whole thing, look for comment blocks, which SHOULD NOT BE IN HERE
	// This code based on replaceAllTextBetweenString:andString:fromDictionary:
	
	NSString *startDelim = @"<!--";
	NSString *endDelim = @"-->";
	
	NSRange range = NSMakeRange(0,[text length]);	// We'll increment this
    
	// Now loop through; looking.
	while (range.length != 0)
	{
		NSRange foundRange = [text rangeFromString:startDelim toString:endDelim options:0 range:range];
		if (foundRange.location != NSNotFound)
		{
			// First, append what was the search range and the found range -- before match -- to output
            {
                NSRange beforeRange = NSMakeRange(range.location, foundRange.location - range.location);
                NSString *before = [text substringWithRange:beforeRange];
                [context writeText:before];
            }
			// Now, figure out what was between those two strings
			{
				NSRange betweenRange = NSMakeRange(foundRange.location, foundRange.length);
				NSString *between = [text substringWithRange:betweenRange];
				[context writeString:between];		// not escaped
			}
			// Now, update things and move on.
			range.length = NSMaxRange(range) - NSMaxRange(foundRange);
			range.location = NSMaxRange(foundRange);
		}
		else
		{
			NSString *after = [text substringWithRange:range];
			[context writeText:after];
			// Now, update to be past the range, to finish up.
			range.location = NSMaxRange(range);
			range.length = 0;
		}
	}
	
    /// Fixed in r18043 so we don't need it here, this should take out problem I was having with two spaces in a comment
    //#warning PATCH here to deal with WEBKIT BUG -- 10636   http://bugs.webkit.org/show_bug.cgi?id=10636
    //	if ([self respondsToSelector:@selector(isContentEditable)] && [(DOMHTMLElement *)self isContentEditable])
    //	{
    //		NSString *twoSpaces = @"  ";
    //		NSString *nbsp = [NSString stringWithUTF8String:"\xc2\xa0"]; // non-breaking-space
    //		NSString *replacePattern = [NSString stringWithUTF8String:"\xc2\xa0 "]; // {non-breaking-space, ' '}
    //		[buf replaceOccurrencesOfString:nbsp withString:@" " options:NSLiteralSearch range:NSMakeRange(0, [buf length])];
    //		[buf replaceOccurrencesOfString:twoSpaces withString:replacePattern options:NSBackwardsSearch range:NSMakeRange(0, [buf length])];
    //	}
    
    return [self nextSibling];
}

@end


#pragma mark -


@implementation DOMComment (SVHTMLContext)

- (DOMNode *)writeHTMLToContext:(SVHTMLContext *)context;
{
	NSString *comment = [self data];
	comment = [comment stringByReplacing:@"--" with:@"- -"];	// don't allow any double-dashes!
	[context writeHTMLString:[NSString stringWithFormat:@"<!-- %@ -->", comment]];
    
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


