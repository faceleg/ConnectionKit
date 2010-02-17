//
//  SVDOMController.m
//  Sandvox
//
//  Created by Mike on 13/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVDOMController.h"

#import "SVContentObject.h"
#import "SVHTMLContext.h"
#import "SVWebEditorViewController.h"

#import "DOMNode+Karelia.h"


@implementation SVDOMController

#pragma mark Dealloc

- (void)dealloc
{
    [_context release];
    [super dealloc];
}

#pragma mark Content

- (id)initWithContentObject:(SVContentObject *)contentObject
              inDOMDocument:(DOMDocument *)document;
{
    // See header for what steps are
    
    //  1)
    DOMHTMLElement *element = [contentObject elementForEditingInDOMDocument:document];
    
    //  2)
    self = [self initWithHTMLElement:element];
    
    //  3)
    [self setRepresentedObject:contentObject];
    
    //  4)
    if (![contentObject shouldPublishEditingElementID])
    {
        [element setIdName:nil];
    }
    
    return self;
}

- (void)createHTMLElement
{
    // Gather the HTML
    NSMutableString *htmlString = [[NSMutableString alloc] init];
    
    SVHTMLContext *context = [[SVHTMLContext alloc] initWithStringStream:htmlString];
    [context copyPropertiesFromContext:[self HTMLContext]];
    
    [context push];
    [self writeRepresentedObjectHTML];
    [context pop];
    
    [context release];
    
    
    // Create DOM objects from HTML
    DOMDocumentFragment *fragment = [[self HTMLDocument]
                                     createDocumentFragmentWithMarkupString:htmlString
                                     baseURL:[[self HTMLContext] baseURL]];
    
    DOMHTMLElement *element = [fragment firstChildOfClass:[DOMHTMLElement class]];  OBASSERT(element);
    [self setHTMLElement:element];
}

- (void)writeRepresentedObjectHTML;
{
    [[self representedObject] writeHTML];
}

@synthesize HTMLContext = _context;

#pragma mark Updating

- (void)update;
{
    [super update]; // does nothing, but hey, might as well
    _needsUpdate = NO;
}

@synthesize needsUpdate = _needsUpdate;

- (void)setNeedsUpdate;
{
    // Try to get hold of the controller in charge of update coalescing
    SVWebEditorView *webEditor = [self webEditor];
	id controller = (id)[webEditor delegate];
    if ([controller respondsToSelector:@selector(scheduleUpdate)] || !webEditor)
    {
        _needsUpdate = YES;
        [controller performSelector:@selector(scheduleUpdate)];
    }
    else
    {
        [self update];
    }
}

- (void)updateIfNeeded; // recurses down the tree
{
    if ([self needsUpdate])
    {
        [self update];
    }
    
    [super updateIfNeeded];
}

#pragma mark Editing

- (BOOL)isEditable { return YES; }

#pragma mark Dispatching Messages

- (void)doCommandBySelector:(SEL)aSelector;
{
    if ([self respondsToSelector:aSelector])
    {
        [self performSelector:aSelector];
    }
    else
    {
        NSBeep();
    }
}

@end


#pragma mark -


@implementation SVWebEditorItem (SVDOMController)

#pragma mark Updating

- (void)update; { }

- (void)updateIfNeeded; // recurses down the tree
{
    // The update may well have meant no children need updating any more. If so, no biggie as this recursion should do nothing
    [[self childWebEditorItems] makeObjectsPerformSelector:_cmd];
}

#pragma mark WebEditorViewController

- (SVWebEditorViewController *)webEditorViewController;
{
    SVWebEditorViewController *result = (id)[[self webEditor] dataSource];
    if (result) OBASSERT([result isKindOfClass:[SVWebEditorViewController class]]);
    return result;
}

@end

