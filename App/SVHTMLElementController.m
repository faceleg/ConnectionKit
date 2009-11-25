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

- (id)initWithHTMLDocument:(DOMHTMLDocument *)document;
{
    self = [self init];
    _DOMDocument = [document retain];
    return self;
}
@synthesize HTMLDocument = _DOMDocument;

- (id)initWithHTMLElement:(DOMHTMLElement *)element;
{
    self = [self init];
    [self setHTMLElement:element];
    return self;
}

- (void)dealloc
{
    [_DOMDocument release];
    [_DOMElement release];
    [_representedObject release];
    
    [super dealloc];
}

#pragma mark HTML Element

@synthesize HTMLElement = _DOMElement;
- (DOMHTMLElement *)HTMLElement
{
    if (![self isHTMLElementLoaded]) [self loadHTMLElement];
    
    OBPOSTCONDITION(_DOMElement);   // should be an exception, not assertion
    return _DOMElement;
}

- (void)loadHTMLElement
{
    // Nothing to do by default
}

- (BOOL)isHTMLElementLoaded { return (_DOMElement != nil); }

#pragma mark Represented Object

@synthesize representedObject = _representedObject;

@end
