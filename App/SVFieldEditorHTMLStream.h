//
//  SVFieldEditorHTMLStream.h
//  Sandvox
//
//  Created by Mike on 10/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

//  To get HTML out of the DOM and into the model, the DOM nodes are written to an HTML context. SVHTMLContext does a pretty good job out of the box, but SVFieldEditorHTMLStream has a few extra tricks up its sleeve:
//
//  -   Writing element start tags is performed lazily; when you open an element, it is queued up on an internal stack and only actually written when it is time to write some following non-start tag content. If the element turns out to be empty, it can be removed from the DOM, and wiped from the stack without any actual writing ever having taken place.
//
//  -   Only a small whitelist of elements, attributes and styling are permitted. Anything failing to make the grade will be removed from the DOM and not actually written to the context.


#import "KSHTMLOutputStream+DOM.h"


@interface SVFieldEditorHTMLStream : KSHTMLOutputStream
{
  @private
    NSMutableArray  *_pendingStartTagDOMElements;
    NSMutableArray  *_pendingEndDOMElements;
}


#pragma mark Writing

// Overrides super's implementation to delete or modify some elements rather than really write them. The correct result is still returned so that the context can carry on recursing correctly.
- (DOMNode *)writeDOMElement:(DOMElement *)element;

// Elements used for styling are worthless if they have no content of their own. We treat them specially by buffering internally until some actual content gets written. If there is none, go ahead and delete the element instead. Shouldn't need to call this directly; -writeDOMElement: does so internally.
- (DOMNode *)writeStylingDOMElement:(DOMElement *)element;

// Shouldn't need to call directly; -writeStylingDOMElement: does so internally
- (DOMNode *)endStylingDOMElement:(DOMElement *)element;

- (DOMNode *)replaceDOMElementIfNeeded:(DOMElement *)element;

- (void)writePendingEndTags;


#pragma mark Tag Whitelist
+ (BOOL)validateTagName:(NSString *)tagName;
+ (BOOL)isElementWithTagNameContent:(NSString *)tagName;


#pragma mark Attribute Whitelist
- (BOOL)validateAttribute:(NSString *)attributeName;


#pragma mark Styling Whitelist
- (BOOL)validateStyleProperty:(NSString *)propertyName;
- (void)removeUnsupportedCustomStyling:(DOMCSSStyleDeclaration *)style;


@end
