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

- (NSString *)HTMLString;
{
    NSString *result;
    if ([[SVHTMLContext currentContext] isEditable])
    {
        result = [NSString stringWithFormat:
                  @"<%@ id=\"%@\">%@</%@>",
                  [self tagName],
                  [self editingElementID],
                  [self innerHTMLString],
                  [self tagName]];
    }
    else
    {
        result = [NSString stringWithFormat:
                  @"<%@>%@</%@>",
                  [self tagName],
                  [self innerHTMLString],
                  [self tagName]];
    }
    
    return result;
}

- (void)setHTMLStringFromElement:(DOMHTMLElement *)element;
{
    //  Use the element to update our tagName, inner HTML, and inline graphics
    [self setTagName:[element tagName]];
    [self setInnerHTMLArchiveString:[element innerHTML]];
}

@dynamic innerHTMLArchiveString;

- (NSString *)innerHTMLString;
{
    NSString *result = [[self class] innerHTMLStringWithArchive:[self innerHTMLArchiveString]
                                           inlineContentObjects:[self inlineGraphics]];
    
    return result;
}

+ (NSString *)innerHTMLStringWithArchive:(NSString *)innerHTMLArchiveString
                    inlineContentObjects:(NSSet *)contentObjects;
{
    return innerHTMLArchiveString;
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
