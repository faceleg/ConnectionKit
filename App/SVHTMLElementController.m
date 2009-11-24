//
//  SVHTMLElementController.m
//  Sandvox
//
//  Created by Mike on 24/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVHTMLElementController.h"


@implementation SVHTMLElementController

#pragma mark Init & Dealloc

- (id)initWithHTMLElement:(DOMHTMLElement *)element;
{
    self = [self init];
    [self setHTMLElement:element];
    return self;
}

- (void)dealloc
{
    [_DOMElement release];
    [_representedObject release];
    
    [super dealloc];
}

#pragma mark HTML Element

@synthesize HTMLElement = _DOMElement;
- (DOMHTMLElement *)HTMLElement
{
    OBPOSTCONDITION(_DOMElement);   // should be an exception, not assertion
    return _DOMElement;
}

- (BOOL)isHTMLElementLoaded { return (_DOMElement != nil); }

#pragma mark Represented Object

@synthesize representedObject = _representedObject;

@end
