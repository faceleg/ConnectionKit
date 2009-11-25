//
//  SVWebEditorItem.m
//  Sandvox
//
//  Created by Mike on 24/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorItem.h"

#import "SVBodyElement.h"
#import "SVHTMLContext.h"

#import "DOMNode+Karelia.h"


@implementation SVWebEditorItem

#pragma mark Accessors

- (void)loadHTMLElement
{
    // Try to create HTML corresponding to our content (should be a Pagelet or plug-in)
    NSString *htmlString = [self representedObjectHTMLString];
    OBASSERT(htmlString);
    
    DOMDocumentFragment *fragment = [[self HTMLDocument]
                                     createDocumentFragmentWithMarkupString:htmlString
                                     baseURL:nil];
    
    DOMHTMLElement *element = [fragment firstChildOfClass:[DOMHTMLElement class]];  OBASSERT(element);
    [self setHTMLElement:element];
}

- (NSString *)representedObjectHTMLString;
{
    SVHTMLContext *context = [self HTMLContext];
    [[context class] pushContext:context];  // ignored if context is nil
    
    NSString *result = [[self representedObject] HTMLString];
    
    [[context class] popContext];
    
    return result;
}

- (DOMElement *)DOMElement { return [self HTMLElement]; }

- (BOOL)isEditable { return NO; }

@end
