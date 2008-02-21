//
//  DOM+WebViewTextEditing.m
//  Marvel
//
//  Created by Mike on 19/12/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "DOM+KTWebViewController.h"

#import "DOMNode+KTExtensions.h"
#import "NSString+Karelia.h"


@implementation DOMNode (KTWebViewController)

/*!	Determines what node, if any, is "selectable" -- e.g. editable text or a photo element.
To find out of it's editable, try
[self isEditableElement:selectedNode]
*/
- (DOMHTMLElement *)firstSelectableParentNode
{
	DOMHTMLElement *result = nil;
	
	DOMNode *aNode = self;
	if ([aNode isKindOfClass:[DOMCharacterData class]]) {
		aNode = [aNode parentNode];	// get up to the element
	}
	
	while (aNode && [aNode isKindOfClass:[DOMHTMLElement class]] && ![aNode isKindOfClass:[DOMHTMLBodyElement class]])
	{
		// If we have an ID k-_______ then we found it
		
		if (nil == result)
		{
			NSString *idValue = [((DOMHTMLElement *)aNode) getAttribute:@"id"];
			if ([idValue hasPrefix:@"k-"])
			{
				result = (DOMHTMLElement *)aNode;				// save for later
				break;
			}
		}
		// Now continue up the chain to the parent.
		aNode = [aNode parentNode];
	}
	
	return result;
}

/*!	Called from javascript "replaceText" -- replace the node with just some text.
*/
- (void)replaceWithText:(NSString *)aText
{
	DOMDocument *doc = [self ownerDocument];
	DOMText *text = [doc createTextNode:aText];
	
	[[DOMNode class] node:[self parentNode] replaceChild:text :self];
	
	NSUndoManager *undoManager = [[[doc webFrame] webView] undoManager];
	[undoManager setActionName:NSLocalizedString(@"Insert Text","ActionName: Insert Text")];
}

@end



@implementation DOMHTMLElement (KTWebViewController)

- (BOOL)isImageable;
{
	NSString *class = [self className];
	BOOL result = [[class componentsSeparatedByWhitespace] containsObject:@"kImageable"];
	return result;
}

/*	If the receiver's first child element is a <span class="in">
 */
- (BOOL)hasSpanIn
{
	BOOL result = NO;
	
	if ([self hasChildNodes] )
	{
		DOMNode *firstChild = [self firstChild];
		if ([firstChild isKindOfClass:[DOMHTMLElement class]]
			&& [[((DOMHTMLElement *)firstChild) tagName] isEqualToString:@"SPAN"])
		{
			if ([[((DOMHTMLElement *)firstChild) className] isEqualToString:@"in"])
			{
				result = YES;
			}
		}
	}
	
	return result;
}

@end
