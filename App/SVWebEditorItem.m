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

- (void)dealloc
{
    [_bodyText release];
    [super dealloc];
}

#pragma mark Accessors

- (void)loadHTMLElement
{
    // Try to create HTML corresponding to our content (should be a Pagelet or plug-in)
    NSString *htmlString = [self representedObjectHTMLString];
    OBASSERT(htmlString);
    
    DOMDocumentFragment *fragment = [[self HTMLDocument]
                                     createDocumentFragmentWithMarkupString:htmlString
                                     baseURL:[[self HTMLContext] baseURL]];
    
    DOMHTMLElement *element = [fragment firstChildOfClass:[DOMHTMLElement class]];  OBASSERT(element);
    [self setHTMLElement:element];
}

@synthesize bodyText = _bodyText;

- (NSString *)representedObjectHTMLString;
{
    SVHTMLContext *context = [self HTMLContext];
    
    [context push];
    NSString *result = [[self representedObject] HTMLString];
    [context pop];
    
    return result;
}

- (DOMElement *)DOMElement { return [self HTMLElement]; }

- (BOOL)isEditable { return NO; }

@end
