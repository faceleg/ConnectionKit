//
//  WEKDOMController.m
//  Sandvox
//
//  Created by Mike on 24/11/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "WEKDOMController.h"
#import <WebKit/WebKit.h>


@interface WEKDOMEventListener : NSObject <DOMEventListener>
{
@private
    id <DOMEventListener>   _target;    // weak ref
}

@property(nonatomic, assign) id <DOMEventListener> eventsTarget;

@end


#pragma mark -


@implementation WEKDOMController

#pragma mark Init & Dealloc

- (id)initWithIdName:(NSString *)elementID ancestorNode:(DOMNode *)node;
{
    if (self = [self init])
    {
        _elementID = [elementID copy];
        if (node || elementID) [self setAncestorNode:node];
    }
    
    return self;
}

- (id)initWithHTMLElement:(DOMHTMLElement *)element;
{
    self = [self init];
    [self setHTMLElement:element];
    return self;
}

- (void)dealloc
{
    [_eventListener setEventsTarget:nil];
    
    [_elementID release];
    [_ancestor release];
    [_DOMElement release];
    [_eventListener release];
    [_representedObject release];
    
    [super dealloc];
}

#pragma mark DOM

@synthesize HTMLElement = _DOMElement;
- (DOMHTMLElement *)HTMLElement
{
    if (!_DOMElement)
    {
        [self loadHTMLElement];
        OBASSERT(_DOMElement);
    }
    return _DOMElement;
}

- (void)loadHTMLElement
{
    NSString *idName = [self elementIdName];
    if (idName)
    {
        DOMHTMLElement *element = nil;
        DOMNode *node = [self ancestorNode];
        
        if ([node respondsToSelector:@selector(getElementById:)])
        {
            // Load the element
            element = [(id)node getElementById:idName];
        }
        
        if (!element)
        {
            // Search through all descendants of the node
            DOMNodeIterator *iterator = [[node ownerDocument] createNodeIterator:node
                                                                      whatToShow:DOM_SHOW_ELEMENT
                                                                          filter:nil
                                                          expandEntityReferences:NO];
            
            while (element = (DOMHTMLElement *)[iterator nextNode])
            {
                if ([[element idName] isEqualToString:idName]) break;
            }
            
            [iterator detach];
        }
        
        [self setHTMLElement:element];
    }
}

- (BOOL)isHTMLElementLoaded { return (_DOMElement != nil); }

@synthesize elementIdName = _elementID;

- (DOMRange *)DOMRange; // returns -HTMLElement as a range
{
    DOMElement *element = [self HTMLElement];
    DOMRange *result = [[element ownerDocument] createRange];
    [result selectNode:element];
    return result;
}

#pragma mark Ancestor

@synthesize ancestorNode = _ancestor;
- (void)setAncestorNode:(DOMNode *)node;
{
    OBPRECONDITION(node);
    [node retain];
    [_ancestor release]; _ancestor = node;
}

- (DOMHTMLDocument *)HTMLDocument;
{
    id result = [self ancestorNode];
    if (![result isKindOfClass:[DOMHTMLDocument class]]) result = nil;
    return result;
}

#pragma mark Events

- (id <DOMEventListener>)eventsListener;
{
    if (!_eventListener)
    {
        _eventListener = [[WEKDOMEventListener alloc] init];
        [_eventListener setEventsTarget:(id <DOMEventListener>)self];   // expect subclasses to conform
    }
    return _eventListener;
}

#pragma mark Content

@synthesize representedObject = _representedObject;

@end


#pragma mark -


@implementation WEKDOMEventListener

@synthesize eventsTarget = _target;

- (void)handleEvent:(DOMEvent *)event;
{
    [[self eventsTarget] handleEvent:event];
}

@end
