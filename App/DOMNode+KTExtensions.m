//
//  DOMNode+KTExtensions.m
//  Marvel
//
//  Created by Terrence Talbot on 5/4/05.
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//

#import "DOMNode+KTExtensions.h"

#import "NSColor+Karelia.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "KSURLFormatter.h"

#import "WebEditingKit.h"
#import "NSScanner+Karelia.h"

#import "Debug.h"


@interface DOMNode (KTExtensionsPrivate)
- (DOMNode *)ks_replaceWithChildNodes;
- (NSString *)textContent;
@end

#pragma mark -


@implementation DOMNode ( KTExtensions )

+ (BOOL)isSingleLineFromDOMNodeClass:(NSString *)aClass;
{
	NSArray *classes = [aClass componentsSeparatedByWhitespace];
	return [classes containsObject:@"kLine"];
}

+ (BOOL)isEditableFromDOMNodeClass:(NSString *)aClass;
{
	NSArray *classes = [aClass componentsSeparatedByWhitespace];
	BOOL result = [classes containsObject:@"kBlock"] || [classes containsObject:@"kLine"];
	if ([classes containsObject:@"HTMLElement"])
	{
		result = NO;	// NOT editable if it's an HTML element.
	}
	return result;
}

+ (BOOL)isSummaryFromDOMNodeClass:(NSString *)aClass;
{
	NSArray *classes = [aClass componentsSeparatedByWhitespace];
	return [classes containsObject:@"kSummary"];
}

+ (BOOL)isImageFromDOMNodeClass:(NSString *)aClass;
{
	NSArray *classes = [aClass componentsSeparatedByWhitespace];
	return [classes containsObject:@"kImage"];
}

+ (BOOL)isHTMLElementFromDOMNodeClass:(NSString *)aClass;
{
	NSArray *classes = [aClass componentsSeparatedByWhitespace];
	return [classes containsObject:@"HTMLElement"];
}


+ (BOOL)isLinkableFromDOMNodeClass:(NSString *)aClass;
{
	NSArray *classes = [aClass componentsSeparatedByWhitespace];
	return [classes containsObject:@"kBlock"];
}


#pragma mark parent elements

- (BOOL)isContainedByElementOfClass:(Class)aClass
{
	DOMNode *parent = [self parentNode];
	if ( (nil == parent) || [parent isMemberOfClass:[DOMHTMLDocument class]] )
	{
		return NO;
	}
	if  ( [parent isMemberOfClass:aClass] )
	{
		return YES;
	}
	else
	{
		return [parent isContainedByElementOfClass:aClass];
	}
}

- (id)immediateContainerOfClass:(Class)aClass
{
	DOMNode *parent = [self parentNode];
	if ( nil == parent )
	{
		return nil;
	}
	if ( [parent isMemberOfClass:aClass] )
	{
		return parent;
	}
	else
	{
		return [parent immediateContainerOfClass:aClass];
	}
}

- (BOOL)hasChildOfClass:(Class)aClass
{
	if ( [self hasChildNodes] )
	{
		DOMNodeList *nodes = [self childNodes];
		int i;
		int length = [nodes length];
		for ( i=0; i<length; i++ )
		{
			id node = [nodes item:i];
			if ( [node isMemberOfClass:aClass] )
			{
				return YES;
			}
			else if ( [node hasChildOfClass:aClass] )
			{
				return YES;
			}
		}
	}
	
	return NO;
}

#pragma mark child elements

/*! recursive method that returns all instances of a particular element */

- (NSArray *)sv_descendantNodesOfClass:(Class)aClass
{
	NSMutableArray *array = [NSMutableArray array];
	
	if ( [self isKindOfClass:aClass] )
	{
		[array addObject:self];
	}
	 
	if ( [self hasChildNodes] )
	{
		// This could potentially be rewritten to use DOMNodeIterator, perhaps faster
        
        DOMNodeList *nodes = [self childNodes];
		int i;
		int length = [nodes length];
		for ( i=0; i<length; i++ )
		{
			id node = [nodes item:i];
			[array addObjectsFromArray:[node sv_descendantNodesOfClass:aClass]];
		}
	}
	
	return [NSArray arrayWithArray:array];
}

- (NSArray *)anchorElements
{
	return [self sv_descendantNodesOfClass:[DOMHTMLAnchorElement class]];
}

- (NSArray *)divElements
{
	return [self sv_descendantNodesOfClass:[DOMHTMLDivElement class]];
}

- (NSArray *)imageElements
{
	return [self sv_descendantNodesOfClass:[DOMHTMLImageElement class]];
}

- (NSArray *)linkElements
{
	return [self sv_descendantNodesOfClass:[DOMHTMLLinkElement class]];
}

- (NSArray *)objectElements
{
	return [self sv_descendantNodesOfClass:[DOMHTMLObjectElement class]];
}

#pragma mark inner/outer HTML

- (void)makePlainTextWithSingleLine:(BOOL)aSingleLine
{
	DOMNodeIterator *it = [[self ownerDocument] createNodeIterator:self whatToShow:DOM_SHOW_TEXT filter:nil expandEntityReferences:YES];
	DOMNode *subNode;
	NSMutableString *buf = [NSMutableString string];
	
	while ((subNode = [it nextNode]))
	{
		[buf appendString:[subNode nodeValue]];
	}
	
	NSString *justString = buf;
	if (aSingleLine)
	{
		justString = [buf condenseWhiteSpace];
	}
	
	
	// Now perform surgery on the node to change it into just a text node
	while ( [self hasChildNodes] )
	{
		[self removeChild:[self firstChild]];
	}
	
	DOMText *newChild = [[self ownerDocument] createTextNode:justString];
	[self appendChild:newChild];
}

#pragma mark -
#pragma mark Media

- (BOOL)isFileList
{
	NSArray *divElements = [self divElements];
	if ([divElements count] == 0 || [[self childNodes] length] != [divElements count])
	{
		return NO;
	}
	
	
	DOMHTMLDivElement *aDiv;
	for (aDiv in divElements)
	{
		if ([[aDiv childNodes] length] != 1 || ![[aDiv firstChild] isKindOfClass:[DOMText class]])
		{
			return NO;
		}
		
		NSString *URLString = [(DOMText *)[aDiv firstChild] data];     // The URL string WebKit hands us MUST be encoded
        NSURL *URL = [KSURLFormatter URLFromString:URLString];   // again in order for NSURL to accept it
		if (!URL || ![URL isFileURL])
		{
			return NO;
		}
	}
	
	return YES;
}


#pragma mark Additional Utility operations

- (void) appendChildren:(DOMNodeList *)aList
{
	int i, length = [aList length];
	for (i = 0 ; i < length ; i++)
	{
		[self appendChild:[aList item:0]];	// always get the first in the list, since each one will be moved into position 0
	}
}

/*!	Insert a new element.  For instance, if self = P tag, and you create a new TT, then all of P's
	original children become the TT's children .. then TT becomes a child of P.
*/
- (DOMElement *)insertElementIntoTreeNamed:(NSString *)elementName
{

	DOMElement *newElement = [[self ownerDocument] createElement:[elementName uppercaseString]];

	// change my children to be its children
	int i;
	DOMNodeList *childNodes = [self childNodes];
	int length = [childNodes length];
	for ( i = 0 ; i < length ; i++ )
	{
		DOMNode *aChild = [childNodes item:0];
		[newElement appendChild:aChild];
	}
	
	// Now make this new element be my only child
	[self appendChild:newElement];
	
	return newElement;		// return this new element for further manipulation
}

/*!	Hunt down any of the specified element.  This is useful when we insert an element like B, we want to make sure there are no B children underneath, since that would be redundant.
*/
- (void)removeAnyDescendentElementsNamed:(NSString *)elementName
{
	elementName = [elementName uppercaseString];
	DOMNodeIterator *it = [[self ownerDocument] createNodeIterator:self whatToShow:DOM_SHOW_ELEMENT filter:nil expandEntityReferences:YES];
	DOMNode *subNode;
	NSMutableArray *nodesToUnlink = [NSMutableArray array];
	
	while ((subNode = [it nextNode]))
	{
		if (subNode != self)
		{
			DOMElement *theElement = (DOMElement *)subNode;
			if ([[theElement tagName] isEqualToString:elementName])
			{
				[nodesToUnlink addObject:theElement];
			}
		}
	}
	DOMElement *theElement;
	for (theElement in nodesToUnlink) {
		(void)[theElement ks_replaceWithChildNodes];
	}
}

- (DOMNode *) removeStylesRecursive
{
	if ([self hasChildNodes])
	{
		DOMNode *child;
		for ( child = [self firstChild]; nil != child; )
		{
			DOMNode *next = [child nextSibling];		// get it in advance just in case we deleted this child
			(void) [child removeStylesRecursive];
			
			// Point to the sibling to process, which we already fetched
			child = next;
		}
	}
	return self;
}



- (DOMNode *) replaceFakeCDataWithCDATA	// replace "fakecdata" tag with #TEXT underneath to real CDATA.  Returns new node.
{
	DOMNode *result = self;
	
	if ([[self nodeName] isEqualToString:@"FAKECDATA"])
	{
		if ([self hasChildNodes])
		{
			DOMNode *firstChild = [self firstChild];
			if ([firstChild isKindOfClass:[DOMText class]])
			{
				NSString *textData = [[[((DOMText *)firstChild) data] copy] autorelease];
				result = [[self ownerDocument] createCDATASection:textData];
// TODO: Try to make this work.  Or try to get webkit to accept CDATA in setInnerHTML
			}
		}
		else
		{
			result = [[self ownerDocument] createCDATASection:@""];
		}
	}
	else if ([self hasChildNodes])		// not here, recurse into any children
	{
		DOMNode *child;
		for ( child = [self firstChild]; nil != child; )
		{
			DOMNode *next = [child nextSibling];		// get it in advance just in case we deleted this child
			DOMNode *replaced = [child replaceFakeCDataWithCDATA];
			
			if (replaced != child)	// changed?  Replace!
			{
				[self replaceChild:replaced oldChild:child];
			}
			// Point to the sibling to process, which we already fetched
			child = next;
		}
	}
	return result;
}


@end

#pragma mark -


@implementation DOMElement ( KTExtensions )

+ (NSString *)cleanupStyleText:(NSString *)inStyleText restrictUnderlines:(BOOL)aRestrictUnderlines wasItalic:(BOOL *)outWasItalic wasBold:(BOOL *)outWasBold wasTT:(BOOL *)outWasTT;
{
	if (!inStyleText || [inStyleText isEqualToString:@""])  return @"";
	
	OFF((@"inStyleText = %@", inStyleText));
	NSMutableString *styleString = [NSMutableString string];
	BOOL hasStyleOutput = NO;
	
	NSScanner *scanner = [NSScanner scannerWithString:inStyleText];
	NSString *keyValue;
	while ([scanner scanUpToString:@";" intoString:&keyValue])
	{
		[scanner scanString:@";" intoString:nil];
		NSRange whereColon = [keyValue rangeOfString:@":"];
		NSString *key = @"";
		NSString *value = @"";
		
		if (NSNotFound != whereColon.location)
		{
			key = [keyValue substringToIndex:whereColon.location];
			value = [[keyValue substringFromIndex:NSMaxRange(whereColon)] stringByTrimmingWhitespace];
		}
		else
		{
			NSLog(@"Invalid keyValue in style: %@", keyValue);
		}
		
		if ([key isEqualToString:@"font"] || [key isEqualToString:@"font-family"])
		{
			NSString *fontName = value;
			// look for pixels ... if found, skip it
			NSRange wherePx = [value rangeOfString:@"px "];
			if (NSNotFound != wherePx.location)
			{
				fontName = [value substringFromIndex:NSMaxRange(wherePx)];
			}
			NSFont *theFont = [NSFont fontWithName:fontName size:12.0];
			
			// If fixed pitch, mark that -- otherwise, do not output this style
			if (outWasTT && [theFont isFixedPitch])
			{
				*outWasTT = YES;
//				if (NSNotFound != [fontName rangeOfString:@" "].location)
//				{
//					fontName = [NSString stringWithFormat:@"\"%@\"", fontName];
//				}
//				[styleString appendFormat:@"font-family: %@, monospace; ", fontName];
//				hasStyleOutput = YES;
			}

		// Go ahead and append the font text
			[styleString appendString:keyValue];
			[styleString appendString:@"; "];
			hasStyleOutput = YES;
		}
		else if ([key isEqualToString:@"color"])
		{
			if (!aRestrictUnderlines)	// ignore color when we're restricting underlines.
			{
				NSString *namedColor = [[NSColor colorDict] objectForKey:[value uppercaseString]];
				if (nil != namedColor)
				{
					value = namedColor;
				}
				[styleString appendFormat:@"color: %@; ", value];
				hasStyleOutput = YES;
			}
		}
		else if ([keyValue isEqualToString:@"font-weight: bold"] && nil != outWasBold)
		{
			if (outWasBold)
			{
				*outWasBold = YES;
			}
		}
		else if ([keyValue isEqualToString:@"font-style: italic"] && nil != outWasItalic)
		{
			if (outWasItalic)
			{
				*outWasItalic = YES;
			}
		}
		else
		{
			static NSSet *sIgnoreStyles = nil;
			if (nil == sIgnoreStyles)
			{
				// These are styles that really we don't want.  It's just too much precision.  Hopefully nobody disagrees with this!
				sIgnoreStyles = [[NSSet alloc] initWithObjects:
				//	@"word-wrap", @"margin-top", 
				//	@"margin-right", @"margin-bottom", @"margin-left", @"letter-spacing", 
				//	@"margin", @"min-height", @"border-collapse", @"border-spacing", 
				//	@"font-variant",  @"line-height", @"text-indent", @"text-transform",
				//	@"orphans", @"widows", @"word-spacing", 
								 
				// You know, I'm going to take all these out.  Let's give everybody enough rope to hang themselves if that's what they really want :-)
								 
					nil];
			}
			
			if (![sIgnoreStyles containsObject:key]
				&& ![key hasSuffix:@"-khtml"]
				&& ![key hasSuffix:@"-apple"]
				&& ![key hasPrefix:@"-"]
				&& ![key hasPrefix:@"webkit-"]
				&& ![keyValue isEqualToString:@"text-align: auto"]
				&& !(aRestrictUnderlines && [keyValue isEqualToString:@"text-decoration: underline"]) )
					// if restricting underlines mode, don't allow underlines through
			{
				[styleString appendString:keyValue];
				[styleString appendString:@"; "];
				hasStyleOutput = YES;
			}
		}
	}
	if (hasStyleOutput)
	{
		[styleString deleteCharactersInRange:NSMakeRange([styleString length] - 1, 1)];	// take off last char
	}
	OFF((@"styleString = %@", styleString));
	return styleString;
}

- (void)removeJunkFromClass
{
	NSString *class = [self getAttribute:@"class"];
	if (nil != class)
	{
		if ([class hasPrefix:@"khtml"]	|| [class hasPrefix:@"Apple"] )		// what if > 1 class?
		{
			[self removeAttribute:@"class"];
		}
	}
}

- (void)removeJunkFromAttributesRestrictive:(BOOL)aRestrictive wasItalic:(BOOL *)outWasItalic wasBold:(BOOL *)outWasBold wasTT:(BOOL *)outWasTT;

{
	NSString *style = [self getAttribute:@"style"];
	if (nil != style)
	{
		NSString *newStyleText = [DOMElement cleanupStyleText:style
										   restrictUnderlines:aRestrictive
													wasItalic:outWasItalic
													  wasBold:outWasBold
														wasTT:outWasTT];
		if (![newStyleText isEqualToString:@""])
		{
			// Replace style string with new string
			[self setAttribute:@"style" value:newStyleText];
		}
		else
		{
			// Remove style string entirely
			[self removeAttribute:@"style"];
		}
	}
}

- (DOMElement *)removeJunkFromParagraphAllowEmpty:(BOOL)anAllowEmptyParagraphs
{
	DOMElement *result = self;
		
	if ([self hasChildNodes])
	{
		DOMNodeList *childNodes = [self childNodes];
		
		// Check for paragraph within paragraph
		if (1 == [childNodes length] && [[[childNodes item:0] nodeName] isEqualToString:@"P"] )
		{
			[[childNodes item:0] ks_replaceWithChildNodes];
			// continue on....
		}
		
		
		// Check for empty node
		if (!anAllowEmptyParagraphs && 1 == [childNodes length])
		{
			DOMNode *child = [childNodes item:0];
			if ([[child nodeName] isEqualToString:@"BR"])
			{
				// Remove self -- I'm a P with just  BR
				DOMNode *parent = [self parentNode];
				(void)[parent removeChild:self];	// that's it, I'm dead!
				return nil;
			}
		}
		// Alternatively -- look for <BR> + \n
		if (!anAllowEmptyParagraphs && 2 == [childNodes length])
		{
			DOMNode *child0 = [childNodes item:0];
			DOMNode *child1 = [childNodes item:1];
			if ([[child0 nodeName] isEqualToString:@"BR"]
				&& [child1 nodeType] == DOM_TEXT_NODE
				&& [[child1 nodeValue] isEqualToString:@"\n"]
				)
			{
				// Remove self -- I'm a P with just  BR
				DOMNode *parent = [self parentNode];
				(void)[parent removeChild:self];	// that's it, I'm dead!
				return nil;
			}
		}
		
		// check for TT inside P, to change it to pre
		BOOL allWereTT = YES;
		unsigned int i;
		unsigned int length = [childNodes length];
		for ( i = 0 ; i < length ; i++)
		{
			DOMNode *aChild = [childNodes item:i];
			if (![[aChild nodeName] isEqualToString:@"TT"])
			{
				allWereTT = NO;
				break;
			}
		}
		if (allWereTT)
		{
			// create a new PRE node with the TT's children as its children
			DOMElement *newPRE = [[self ownerDocument] createElement:@"PRE"];
			// now append each child's children
			unsigned int childLength = [childNodes length];
			for ( i = 0 ; i < childLength ; i++ )
			{
				DOMNode *aChild = [childNodes item:i];
				[newPRE appendChildren:[aChild childNodes]];
			}
			[[self parentNode] replaceChild:newPRE oldChild:self];
			result = newPRE;
		}
	}
	return result;
}


@end


#pragma mark -


@implementation DOMHTMLElement ( KTExtensions )

/*!	General case  .... look in child nodes and process there.  We call this when we want to recurse
*/

- (DOMNode *) removeStylesRecursive
{
	DOMNode *result = [super removeStylesRecursive];		// call super to deal with children
	if ([result respondsToSelector:@selector(removeAttribute:)])
	{
		[((DOMElement *)result) removeAttribute:@"style"];
	}
	
	return result;
}


@end
