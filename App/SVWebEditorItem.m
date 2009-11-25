//
//  SVWebEditorItem.m
//  Sandvox
//
//  Created by Mike on 24/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorItem.h"

#import "SVBodyElement.h"

#import "DOMNode+Karelia.h"


@implementation SVWebEditorItem

#pragma mark Accessors

- (void)loadHTMLElement
{
    // Try to create HTML corresponding to our content (should be a Pagelet or plug-in)
    SVBodyElement *content = [self representedObject];  OBASSERT(content);
    NSString *htmlString = [content HTMLString];
    
    DOMDocumentFragment *fragment = [[self HTMLDocument]
                                     createDocumentFragmentWithMarkupString:htmlString
                                     baseURL:nil];
    
    DOMHTMLElement *element = [fragment firstChildOfClass:[DOMHTMLElement class]];  OBASSERT(element);
    [self setHTMLElement:element];
}

- (DOMElement *)DOMElement { return [self HTMLElement]; }

- (BOOL)isEditable { return NO; }

@end
