//
//  SVTitleBoxHTMLContext.h
//  Sandvox
//
//  Created by Mike on 10/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

//  A rather specialised HTML Context that writes to a SVBodyParagraph object, splitting it between .archiveString and .links


#import "SVMutableStringHTMLContext.h"


@class SVBodyParagraph;


@interface SVTitleBoxHTMLContext : SVMutableStringHTMLContext
{
  @private
    NSMutableArray  *_unwrittenDOMElements;
}


- (DOMNode *)replaceElementIfNeeded:(DOMElement *)element;


#pragma mark Tag Whitelist
+ (BOOL)validateTagName:(NSString *)tagName;
+ (BOOL)isElementWithTagNameContent:(NSString *)tagName;


#pragma mark Attribute Whitelist
- (BOOL)validateAttribute:(NSString *)attributeName;


#pragma mark Styling Whitelist
- (BOOL)validateStyleProperty:(NSString *)propertyName;
- (void)removeUnsupportedCustomStyling:(DOMCSSStyleDeclaration *)style;


@end
