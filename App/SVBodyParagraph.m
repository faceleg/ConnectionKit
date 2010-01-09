// 
//  SVParagraph.m
//  Sandvox
//
//  Created by Mike on 18/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVBodyParagraph.h"
#import "SVBodyParagraphDOMAdapter.h"

#import "SVPlugInGraphic.h"
#import "SVHTMLContext.h"

#import "NSString+Karelia.h"


@implementation SVBodyParagraph 

@dynamic tagName;
@dynamic inlineGraphics;

- (void)writeHTML;
{
    SVHTMLContext *context = [SVHTMLContext currentContext];
    
    [context writeStartTag:[self tagName]
                    idName:([context isEditable] ? [self editingElementID] : nil)
                 className:nil];
    
    [self writeInnerHTML];
    
    [context writeEndTag:[self tagName]];
}

- (void)setHTMLStringFromElement:(DOMHTMLElement *)element;
{
    //  Use the element to update our tagName, inner HTML, and inline graphics
    [self setTagName:[element tagName]];
    [self setArchiveString:[element innerHTML]];
}

@dynamic archiveString;

- (void)writeInnerHTML;
{
    [[SVHTMLContext currentContext] writeHTMLString:[self archiveString]];
}

- (DOMHTMLElement *)elementForEditingInDOMDocument:(DOMDocument *)document
{
    // Want to make sure it's also got the right tagname
    DOMHTMLElement *result = [super elementForEditingInDOMDocument:document];
    
    if (![[result tagName] isEqualToStringCaseInsensitive:[self tagName]]) result = nil;
    
    return result;
}

- (Class)DOMControllerClass;
{
    return [SVBodyParagraphDOMAdapter class];
}

@end
