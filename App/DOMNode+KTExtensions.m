//
//  DOMNode+KTExtensions.m
//  Marvel
//
//  Created by Terrence Talbot on 5/4/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "DOMNode+KTExtensions.h"

#import "KTMediaContainer.h"
#import "KTMediaManager.h"
#import "NSColor+Karelia.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"

#import <WebKit/WebKit.h>
#import "DOMNodeList+KTExtensions.h"
#import "WebView+Karelia.h"
#import "NSScanner+Karelia.h"

#import "Debug.h"


@interface DOMNode (KTExtensionsPrivate)
- (DOMNode *)unlink;
- (void)combineAdjacentRedundantNodes;
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

#pragma mark -
#pragma mark Index Paths

/*	Traces through the index path to find the node it corresponds to. Returns nil if nothing is found.
 *	Used mainly for resetting the selection after replacing a truncated summary.
 */
- (DOMNode *)descendantNodeAtIndexPath:(NSIndexPath *)indexPath
{
	DOMNode *result = nil;
	
	DOMNode *aParentNode = self;
	unsigned position;
	for (position=0; position<[indexPath length]; position++)
	{
		unsigned anIndex = [indexPath indexAtPosition:position];
		
		DOMNodeList *childNodes = [aParentNode childNodes];
		if ([childNodes length] <= anIndex) {		// Bail if there aren't enough children
			break;	
		}
		
		if (position == [indexPath length] - 1)		// Are we at the end of the path?
		{
			result = [childNodes item:anIndex];
			break;
		}
		else
		{
			aParentNode = [childNodes item:anIndex];
		}
	}
	
	return result;
}

/*	Simply returns an index path describing how to get to this object from the specified node
 *	purely using indexes. Returns nil if the receiver is not a child of the node.
 *	Used mainly for truncated summaries where we need to relocate an equivalent node after it has been replaced.
 */
- (NSIndexPath *)indexPathFromNode:(DOMNode *)node;
{
	NSIndexPath *result = nil;
	
	DOMNode *parent = [self parentNode];
	if (parent)
	{
		unsigned index = [[parent childNodes] indexOfItemIdenticalTo:self];
		OBASSERT(index != NSNotFound);
		
		if (parent == node)
		{
			result = [NSIndexPath indexPathWithIndex:index];
		}
		else
		{
			result = [[parent indexPathFromNode:node] indexPathByAddingIndex:index];
		}
	}
	
	return result;
}

#pragma mark child elements

/*! recursive method that returns all instances of a particular element */

// TODO: this could be rewritten to use DOMNodeIterator, perhaps faster

- (NSArray *)childrenOfClass:(Class)aClass
{
	NSMutableArray *array = [NSMutableArray array];
	
	if ( [self isKindOfClass:aClass] )
	{
		[array addObject:self];
	}
	 
	if ( [self hasChildNodes] )
	{
		DOMNodeList *nodes = [self childNodes];
		int i;
		int length = [nodes length];
		for ( i=0; i<length; i++ )
		{
			id node = [nodes item:i];
			[array addObjectsFromArray:[node childrenOfClass:aClass]];
		}
	}
	
	return [NSArray arrayWithArray:array];
}

- (NSArray *)anchorElements
{
	return [self childrenOfClass:[DOMHTMLAnchorElement class]];
}

- (NSArray *)divElements
{
	return [self childrenOfClass:[DOMHTMLDivElement class]];
}

- (NSArray *)imageElements
{
	return [self childrenOfClass:[DOMHTMLImageElement class]];
}

- (NSArray *)linkElements
{
	return [self childrenOfClass:[DOMHTMLLinkElement class]];
}

- (NSArray *)objectElements
{
	return [self childrenOfClass:[DOMHTMLObjectElement class]];
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

/*!	Ignore everything after the first line
*/
- (void)makeSingleLine;
{
	DOMNodeIterator *it = [[self ownerDocument] createNodeIterator:self whatToShow:DOM_SHOW_TEXT filter:nil expandEntityReferences:YES];
	DOMNode *subNode;
	
	
	while ((subNode = [it nextNode]))
	{
		NSString *theString = [subNode nodeValue];
		if (NSNotFound != [theString rangeOfString:@"\n"].location)
		{
			NSString *newString = [theString condenseWhiteSpace];
			if ([newString isEqualToString:@""])
			{
				[[subNode parentNode] removeChild:subNode];
			}
			else
			{
				[((DOMCharacterData *)subNode) setData:newString];
			}
		}
	}
	
	/* MAYBE BETTER TO DO: 	BOOL isRemoving = NO;
	
	// Iterate through text.  When newline is found, delete everything after that.
	while ((subNode = [it nextNode]))
	{
		if (isRemoving)
		{
			[[subNode parentNode] removeChild:subNode];
		}
		else
		{
			NSString *theString = [subNode nodeValue];
			NSRange *whereNewline = [theString rangeOfString:@"\n"]
				if (NSNotFound != whereNewline.location)
				{
					isRemoving = YES;
					NSString *newString = [theString substringToIndex:whereNewline];
					if ([newString isEqualToString:@""])
					{
						[[subNode parentNode] removeChild:subNode];
					}
					else
					{
						[((DOMCharacterData *)subNode) setData:newString];
					}
				}
		}
	}
*/	
	
	// also remove graphics and unlink anchors & paragraphs from a single line
	it = [[self ownerDocument] createNodeIterator:self whatToShow:DOM_SHOW_ELEMENT filter:nil expandEntityReferences:YES];
	
	while ((subNode = [it nextNode]))
	{
		DOMElement *theElement = (DOMElement *)subNode;
		if ([[theElement tagName] isEqualToString:@"IMG"] || [[theElement tagName] isEqualToString:@"OBJECT"]  || [[theElement tagName] isEqualToString:@"A"])
		{
			[[theElement parentNode] removeChild:theElement];
		}
		else if ( [[theElement tagName] isEqualToString:@"P"] || [[theElement tagName] isEqualToString:@"BR"] || [[theElement tagName] isEqualToString:@"A"] )
		{
			[theElement unlink];
		}
	}
	// remove adjacent elements, which in a single line, are redundant.
	[self combineAdjacentRedundantNodes];
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
	
	
	NSEnumerator *divsEnumerator = [divElements objectEnumerator];
	DOMHTMLDivElement *aDiv;
	while (aDiv = [divsEnumerator nextObject])
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


/*	Run through our child nodes, converting the source of any images to use the
 *	media:// URL scheme.
 *	This method is implemented for both DOMNode and DOMElement since only DOMElement supports the
 *	-getElementsByTagName: method.
 */
- (void)convertImageSourcesToUseSettingsNamed:(NSString *)settingsName forPlugin:(KTAbstractElement *)plugin;
{
	// Since we're a DOMNode, ask evey child to do this method.
	DOMNodeList *children = [self childNodes];
	unsigned i;
	for (i=0; i<[children length]; i++)
	{
		[[children item:i] convertImageSourcesToUseSettingsNamed:settingsName forPlugin:plugin];
	}
}

#pragma mark Additional Utility operations

/*!	When nodes next to each other are the same, like <b>foo</b><b>bar</b> this combines them.
 *
 // TODO:   I know -normalize does this for text nodes. We should check if it works for <b> elements etc.
 //         Then either remove this method, or rename it to have "normalize" in the name.
*/
- (void)combineAdjacentRedundantNodes
{
	if ([self hasChildNodes])
	{
		DOMNodeList *childNodes = [self childNodes];
		int i, length = [childNodes length];
		NSString *followingNodeName = nil;
		for (i = length-1 ; i >=0 ; i--)	// backwards
		{
			DOMNode *child = [childNodes item:i];
			if ([[child nodeName] isEqualToString:followingNodeName])
			{
				DOMNode *followingChild = [childNodes item:i+1];
				DOMNodeList *followingGrandchildren = [followingChild childNodes];
				[child appendChildren:followingGrandchildren];
				[self removeChild:followingChild];		// done with following child
			}
			else
			{
				followingNodeName = [child nodeName];
			}
		}
	}
	[self normalize];
}

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
	NSEnumerator *e = [nodesToUnlink objectEnumerator];
	DOMElement *theElement;
	while ((theElement = [e nextObject])) {
		(void)[theElement unlink];
	}
}

/*!	Called from javascript "replaceElement" ... pressing of "+" button ... puts back an element that was empty
*/
- (DOMHTMLElement *)replaceWithElementName:(NSString *)anElement elementClass:(NSString *)aClass elementID:(NSString *)anID text:(NSString *)aText innerSpan:(BOOL)aSpan innerParagraph:(BOOL)aParagraph
{
	DOMDocument *doc = [self ownerDocument];
	DOMText *text = [doc createTextNode:aText];
	
	DOMHTMLElement *element = (DOMHTMLElement *)[doc createElement:anElement];
	[element setClassName:aClass];
	[element setIdName:anID];
	[element setContentEditable:@"true"];
	
	if (aSpan)
	{
		DOMHTMLElement *span = (DOMHTMLElement *)[doc createElement:@"SPAN"];
		[span setAttribute:@"class" value:@"in"];
	
		[span appendChild:text];
		[element appendChild:span];
	}
	else if ([anElement isEqualToString:@"SPAN"])
    {
        [element appendChild:text];
    }
    else
	{
// OLD BEHAVIOR -- JUST THE TEXT.  INSTEAD, WE WILL PUT THAT INTO A <P>		[element appendChild:text];
		
		DOMHTMLElement *p = (DOMHTMLElement *)[doc createElement:@"P"];
		[p appendChild:text];
		[element appendChild:p];
	}
		
    WebView *webView = [[doc webFrame] webView];
	[webView replaceNode:self withNode:element];

	NSUndoManager *undoManager = [webView undoManager];
	[undoManager setActionName:NSLocalizedString(@"Insert Text","ActionName: Insert Text")];
	return element;	// new node
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



/*!	General case  .... look in child nodes and process there.  We call this when we want to recurse
*/

- (DOMNode *) removeJunkRecursiveRestrictive:(BOOL)aRestrictive allowEmptyParagraphs:(BOOL)anAllowEmptyParagraphs
{
	if ([self hasChildNodes])
	{
		DOMNode *child;
		for ( child = [self firstChild]; nil != child; )
		{
			DOMNode *next = [child nextSibling];		// get it in advance just in case we deleted this child
			(void) [child removeJunkRecursiveRestrictive:aRestrictive allowEmptyParagraphs:anAllowEmptyParagraphs];
			
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


// FIXME: These methods do not account for removing the undo history once the enclosing WebFrame goes away

@implementation DOMNode ( KTUndo )

/*! by passing the parent as an argument, NSInvocation retains parent making this method suitable for Undo */
+ (DOMNode *)node:(DOMNode *)parent appendChild:(DOMNode *)child
{
	DOMDocument *doc = [parent ownerDocument];
	NSUndoManager *undoManager = [[[doc webFrame] webView] undoManager];
	
	// to undo appendChild:, we simply remove the child
	[[undoManager prepareWithInvocationTarget:[DOMNode class]] node:parent removeChild:child];
	
	return [parent appendChild:child];
}

+ (DOMNode *)node:(DOMNode *)parent insertBefore:(DOMNode *)newChild :(DOMNode *)refChild
{
	DOMDocument *doc = [parent ownerDocument];
	NSUndoManager *undoManager = [[[doc webFrame] webView] undoManager];
	
	// to undo insertBefore::, we remove the newChild
	[[undoManager prepareWithInvocationTarget:[DOMNode class]] node:parent removeChild:newChild];
	
	return [parent insertBefore:newChild refChild:refChild];	
}

+ (DOMNode *)node:(DOMNode *)parent removeChild:(DOMNode *)child
{
	DOMDocument *doc = [parent ownerDocument];
	NSUndoManager *undoManager = [[[doc webFrame] webView] undoManager];
	
	// to undo removeChild:, we need to insertBefore:: the correct node
	DOMNode *nextSibling = [child nextSibling];
	if ( nil != nextSibling )
	{
		[[undoManager prepareWithInvocationTarget:[DOMNode class]] node:parent insertBefore:child :nextSibling];
	}
	else
	{
		// if there's no nextSibling, we can just appendChild:
		[[undoManager prepareWithInvocationTarget:[DOMNode class]] node:parent appendChild:child];
	}
	
	return [parent removeChild:child];
}

@end

@implementation DOMHTMLAnchorElement ( KTUndo )
+ (void)element:(DOMHTMLAnchorElement *)anchor setHref:(NSString *)anHref target:(NSString *)aTarget
{
	DOMDocument *doc = [anchor ownerDocument];
	NSUndoManager *undoManager = [[[doc webFrame] webView] undoManager];
	
	// to undo, simply set the original properties
	[[undoManager prepareWithInvocationTarget:[DOMHTMLAnchorElement class]] element:anchor 
																			setHref:[anchor href] 
																			 target:[anchor target]];
	
	[anchor setHref:anHref];
	if ( nil != aTarget )
	{
		[anchor setTarget:aTarget];
	}
	else
	{
		[anchor removeAttribute:@"target"];
	}
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
			value = [[keyValue substringFromIndex:NSMaxRange(whereColon)] trim];
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
			[[childNodes item:0] unlink];
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


/*	Run through our child nodes, converting the source of any images to use the
 *	media:// URL scheme.
 *	This method is implemented for both DOMNode and DOMElement since only DOMElement supports the
 *	-getElementsByTagName: method.
 */
- (void)convertImageSourcesToUseSettingsNamed:(NSString *)settingsName forPlugin:(KTAbstractElement *)plugin;
{
	// If we're an IMG element, convert our source
	if ([self isKindOfClass:[DOMHTMLImageElement class]])
	{
		[(DOMHTMLImageElement *)self convertSourceToUseSettingsNamed:settingsName forPlugin:plugin];
	}
	
	// And then convert any child image elements
	DOMNodeList *childImages = [self getElementsByTagName:@"IMG"];
	unsigned i;
	for (i=0; i<[childImages length]; i++)
	{
		[(DOMHTMLImageElement *)[childImages item:i] convertSourceToUseSettingsNamed:settingsName
																		   forPlugin:plugin];
	}
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


- (DOMNode *) removeJunkRecursiveRestrictive:(BOOL)aRestrictive allowEmptyParagraphs:(BOOL)anAllowEmptyParagraphs
{
	BOOL wasItalic = NO;
	BOOL wasBold = NO;
	BOOL wasTT = NO;
	
	if ( [[self tagName] isEqualToString:@"A"])
	{
		aRestrictive = YES;	// we have an A, so nestings from here on down should be restrictive
							// to pull out pseudo-underlines.
	}
	
	[self removeJunkFromAttributesRestrictive:aRestrictive wasItalic:&wasItalic wasBold:&wasBold wasTT:&wasTT];
	[self removeJunkFromClass];
	
	DOMNode *result = [super removeJunkRecursiveRestrictive:aRestrictive
									   allowEmptyParagraphs:anAllowEmptyParagraphs];		// call super to deal with children
	
	
	// remove P with a BR in it.
	if ([[((DOMElement *)result) tagName] isEqualToString:@"P"])
	{
		result = [(DOMElement *)result removeJunkFromParagraphAllowEmpty:(BOOL)anAllowEmptyParagraphs];
	}
	else if ( [[((DOMElement *)result) tagName] isEqualToString:@"LI"] && ![result hasChildNodes])
	{
		// Remove empty lists, which is what you get when converting rich text with lists with blank lines
		[[result parentNode] removeChild:result];
		return nil;
	}
	
	// OK, node is still alive.  Now maybe insert b and i nodes above.
	if (wasBold)
	{
		result = [result insertElementIntoTreeNamed:@"B"];
		[result removeAnyDescendentElementsNamed:@"B"];
	}
	if (wasItalic)
	{
		result = [result insertElementIntoTreeNamed:@"I"];
		[result removeAnyDescendentElementsNamed:@"I"];
	}
	if (wasTT)
	{
		result = [result insertElementIntoTreeNamed:@"TT"];
		[result removeAnyDescendentElementsNamed:@"TT"];
	}
	[result normalize];		// coalesce stuff, like two contiguous #text nodes
	
	return result;
// TODO: here I should coalesce PRE elements (with a \n #text node between) into a single PRE
}

@end


#pragma mark -


@implementation DOMHTMLImageElement (KTExtensions)

/*	Create a media container object for our source.
 *	Then replace our source URL with an appropriate media:// one.
 *	Depending on the URL scheme, we can either use the local path, or might have to convert to
 *	data first.
 */
- (void)convertSourceToUseSettingsNamed:(NSString *)settingsName forPlugin:(KTAbstractElement *)plugin;
{
	NSURL *sourceURL = [NSURL URLWithString:[self src]];
	if (sourceURL)
	{
		// Create a media container from the URL.
		KTMediaContainer *mediaContainer = nil;
		if ([sourceURL isFileURL])
		{
			mediaContainer = [[plugin mediaManager] mediaContainerWithPath:[sourceURL path]];
		}
		else if ([[sourceURL scheme] isEqualToString:@"svxmedia"])	// Media container already exists
		{
			return;
		}
		else
		{
			// Pull the data for the URL from WebKit. May have to use a private method sometimes.
			WebDataSource *dataSource = [[[self ownerDocument] webFrame] dataSource];
			NSData *data = [[dataSource subresourceForURL:sourceURL] data];
			if (!data && [dataSource respondsToSelector:@selector(_archivedSubresourceForURL:)])
			{
				data = [[dataSource performSelector:@selector(_archivedSubresourceForURL:)
										 withObject:sourceURL] data];
			}
			
			if (data)
			{
				NSString *UTI = [NSString UTIForFilenameExtension:[[sourceURL path] pathExtension]];
				mediaContainer = [[plugin mediaManager] mediaContainerWithData:data
																	  filename:@"pastedGraphic"
																		   UTI:UTI];
			}
		}
		
		
		// Scale the image appropriately
		if (mediaContainer)
		{
			mediaContainer = [mediaContainer imageWithScalingSettingsNamed:settingsName forPlugin:plugin];
		}
		
		
		// Convert our src URL to point to the media
		if (mediaContainer)
		{
			NSString *mediaURL = [[mediaContainer URIRepresentation] absoluteString];
			[self setSrc:mediaURL];
		}
	}
}

@end
