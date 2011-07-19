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

- (id)initWithElementIdName:(NSString *)elementID document:(DOMHTMLDocument *)document;
{
    if (self = [self init])
    {
        _elementID = [elementID copy];
        _document = [document retain];
    }
    
    return self;
}

- (id)initWithElementIdName:(NSString *)elementID documentFragment:(DOMDocumentFragment *)fragment;
{
    if (self = [self init])
    {
        _elementID = [elementID copy];
        _fragment = [fragment retain];
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
    [_document release];
    [_fragment release];
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
        DOMDocument *document = [self HTMLDocument];
        if (document)
        {
            // Load the element
            DOMHTMLElement *element = (DOMHTMLElement *)[document getElementById:idName];
            [self setHTMLElement:element];
        }
        else
        {
            DOMDocumentFragment *fragment = [self documentFragment];
            
            // TODO: ought to search more than top-level of tree
            DOMHTMLElement *anElement = [fragment firstChildOfClass:[DOMHTMLElement class]];
            while (anElement)
            {
                if ([[anElement getAttribute:@"id"] isEqualToString:idName])
                {
                    [self setHTMLElement:anElement];
                }
                
                anElement = [anElement nextSiblingOfClass:[DOMElement class]];
            }
        }
    }
}

- (BOOL)isHTMLElementLoaded { return (_DOMElement != nil); }

@synthesize elementIdName = _elementID;
@synthesize HTMLDocument = _document;
@synthesize documentFragment = _fragment;

- (DOMRange *)DOMRange; // returns -HTMLElement as a range
{
    DOMElement *element = [self HTMLElement];
    DOMRange *result = [[element ownerDocument] createRange];
    [result selectNode:element];
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
