// 
//  SVParagraph.m
//  Sandvox
//
//  Created by Mike on 18/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVBodyParagraph.h"

#import "SVPlugInContentObject.h"
#import "SVHTMLContext.h"


@implementation SVBodyParagraph 

@dynamic tagName;
@dynamic inlineContentObjects;

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

- (NSString *)innerHTMLString;
{
    return [self archivedInnerHTMLString];
}

- (void)setHTMLStringFromDOMHTMLElement:(DOMHTMLElement *)element;
{
    //  Use the element to update our tagName, inner HTML, and inline content objects
    [self setTagName:[element tagName]];
    [self setArchivedInnerHTMLString:[element innerHTML]];
}

@dynamic archivedInnerHTMLString;

@end
