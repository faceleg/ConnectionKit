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
    [_eventListener setEventsTarget:nil];
    [self setChildDOMControllers:nil];
    
    [_DOMDocument release];
    [_context release];
    [_DOMElement release];
    [_eventListener release];
    [_representedObject release];
    
    [super dealloc];
}

#pragma mark Tree

/*  Fairly basic heirarchy maintenance stuff here
 */

@synthesize childDOMControllers = _childControllers;
- (void)setChildDOMControllers:(NSArray *)controllers
{
    [[self childDOMControllers] makeObjectsPerformSelector:@selector(setParentDOMController:)
                                                withObject:nil];
    
    controllers = [controllers copy];
    [_childControllers release]; _childControllers = controllers;
    
    [controllers makeObjectsPerformSelector:@selector(setParentDOMController:)
                                 withObject:self];
}

@synthesize parentDOMController = _parentController;

- (void)addChildDOMController:(SVHTMLElementController *)controller;
{
    OBPRECONDITION(controller);
    
    NSArray *children = [[self childDOMControllers] arrayByAddingObject:controller];
    if (!children) children = [NSArray arrayWithObject:controller];
    [_childControllers release]; _childControllers = [children copy];
    
    [controller setParentDOMController:self];
}

- (void)removeFromParentDOMController;
{
    [self setParentDOMController:nil];
    
    SVHTMLElementController *parent = [self parentDOMController];
    
    NSMutableArray *children = [[parent childDOMControllers] mutableCopy];
    [children removeObject:self];
    
    if (parent)
    {
        [parent->_childControllers release]; parent->_childControllers = children;
    }
}

#pragma mark DOM

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

- (SVDOMEventListener *)eventListener;
{
    if (!_eventListener)
    {
        _eventListener = [[SVDOMEventListener alloc] init];
        [_eventListener setEventsTarget:(id <DOMEventListener>)self];   // expect subclasses to conform
    }
    return _eventListener;
}

- (void)update; { }

- (void)setNeedsUpdate; { [self update]; }

#pragma mark Content

@synthesize representedObject = _representedObject;
@synthesize HTMLContext = _context;

@end
