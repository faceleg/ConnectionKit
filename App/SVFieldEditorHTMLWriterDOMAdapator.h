//
//  SVFieldEditorHTMLWriterDOMAdapator.h
//  Sandvox
//
//  Created by Mike on 10/01/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

//  To get HTML out of the DOM and into the model, the DOM nodes are written to an HTML context. SVHTMLContext does a pretty good job out of the box, but SVFieldEditorHTMLWriter has a few extra tricks up its sleeve:
//
//  -   Writing element start tags is performed lazily; when you open an element, it is queued up on an internal stack and only actually written when it is time to write some following non-start tag content. If the element turns out to be empty, it can be removed from the DOM, and wiped from the stack without any actual writing ever having taken place.
//
//  -   Only a small whitelist of elements, attributes and styling are permitted. Anything failing to make the grade will be removed from the DOM and not actually written to the context.


#import "KSXMLWriterDOMAdaptor.h"
#import "KSStringWriter.h"


@class SVTextAttachment;


@interface SVFieldEditorHTMLWriterDOMAdapator : KSXMLWriterDOMAdaptor
{
    KSStringWriter  *_output;
  @private
    NSMutableArray  *_pendingStartTagDOMElements;
    NSMutableSet    *_attachments;
    
    NSMutableArray  *_pendingEndDOMElements;
    
    BOOL    _allowsImages;
    BOOL    _allowsLinks;
}

// Constructs intermediate HTML Writer for you
- (id)initWithOutputStringWriter:(KSStringWriter *)output;


#pragma mark Properties
@property(nonatomic) BOOL importsGraphics;
@property(nonatomic) BOOL allowsLinks;


#pragma mark Attachments
- (NSSet *)textAttachments;
- (void)writeTextAttachment:(SVTextAttachment *)attachment;


#pragma mark Cleanup
- (DOMNode *)handleInvalidDOMElement:(DOMElement *)element;
- (DOMElement *)replaceDOMElement:(DOMElement *)element withElementWithTagName:(NSString *)tagName;
- (void)moveDOMNodeToAfterParent:(DOMNode *)node includeFollowingSiblings:(BOOL)moveSiblings;


#pragma mark Tag Whitelist
- (BOOL)validateElement:(NSString *)tagName;    // is it valid right now?
+ (BOOL)validateElement:(NSString *)tagName;    // can this sort of element ever be valid?
+ (BOOL)isElementWithTagNameContent:(NSString *)tagName;


#pragma mark Attributes

- (NSString *)validateAttribute:(NSString *)attributeName
                          value:(NSString *)attributeValue
                      ofElement:(NSString *)tagName;

- (void)buildAttributesForDOMElement:(DOMElement *)element element:(NSString *)elementName;

#pragma mark Styling Whitelist
- (BOOL)validateStyleProperty:(NSString *)propertyName ofElement:(NSString *)element;
- (void)removeUnsupportedCustomStyling:(DOMCSSStyleDeclaration *)style fromElement:(NSString *)element;


#pragma mark Buffering
- (void)outputWillFlush:(NSNotification *)notification;


@end

