//
//  SVWebTextField.m
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebTextField.h"


@implementation SVWebTextField

- (void)dealloc
{
    [_placeholder release];
    [super dealloc];
}

@synthesize placeholderString = _placeholder;
- (void)setPlaceholderString:(NSString *)placeholder
{
    placeholder = [placeholder copy];
    [_placeholder release]; _placeholder = placeholder;
    
    if ([[self HTMLString] length] == 0)
    {
        [[self HTMLElement] setInnerText:placeholder];
    }
}

- (void)setHTMLElement:(DOMHTMLElement *)element
{
    [super setHTMLElement:element];
    
    if ([[self HTMLString] length] == 0)
    {
        [[self HTMLElement] setInnerText:[self placeholderString]];
    }
}

- (void)setHTMLString:(NSString *)html
{
    if ([html length] > 0)
    {
        [super setHTMLString:html];
    }
    else
    {
        [[self HTMLElement] setInnerText:[self placeholderString]];
    }
}

@end
