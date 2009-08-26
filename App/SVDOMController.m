//
//  SVDOMElementController.m
//  Marvel
//
//  Created by Mike on 21/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVDOMController.h"


@implementation SVDOMController

- (void)dealloc
{
    [_element release];
    
    [super dealloc];
}

- (DOMHTMLElement *)DOMElement
{
    if (!_element) [self loadDOMElement];
    
    if (!_element)
    {
        [NSException raise:NSInvalidArgumentException
                    format:@"%@ unable to locate DOMElement", self];
    }
    
    return _element;
}

- (void)setDOMElement:(DOMHTMLElement *)element
{
    [element retain];
    [_element release];
    _element = element;
}

- (void)loadDOMElement
{
    // As DOM Elements do not come in nibs, there's no way we can load them at the moment.
    SUBCLASSMUSTIMPLEMENT;
}

- (BOOL)DOMElementIsLoaded
{
    BOOL result = (_element != nil);
    return result;
}

@end
