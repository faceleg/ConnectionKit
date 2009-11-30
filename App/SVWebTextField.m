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
    // Store placeholder
    placeholder = [placeholder copy];
    [_placeholder release]; _placeholder = placeholder;
    
    // Display new placeholder if appropriate
    if ([[self HTMLString] length] == 0)
    {
        [[self HTMLElement] setInnerText:placeholder];
    }
}

- (void)setHTMLElement:(DOMHTMLElement *)element
{
    [super setHTMLElement:element];
    
    // Once attached to our DOM node, give it the placeholder text if needed
    if ([[self HTMLString] length] == 0 && [self placeholderString])
    {
        [[self HTMLElement] setInnerText:[self placeholderString]];
    }
}

@end
