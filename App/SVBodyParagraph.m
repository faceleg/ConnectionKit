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
@dynamic archivedInnerHTMLString;
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
                  [self archivedInnerHTMLString],
                  [self tagName]];
    }
    else
    {
        result = [NSString stringWithFormat:
                  @"<%@>%@</%@>",
                  [self tagName],
                  [self archivedInnerHTMLString],
                  [self tagName]];
    }
    
    return result;
}

@end
