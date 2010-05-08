//
//  SVDOMController.m
//  Sandvox
//
//  Created by Mike on 13/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVDOMController.h"

#import "SVSidebarDOMController.h"
#import "SVWebEditorHTMLContext.h"
#import "SVWebEditorViewController.h"

#import "DOMNode+Karelia.h"


@implementation SVDOMController

#pragma mark Dealloc

- (void)dealloc
{
    [_context release];
    [super dealloc];
}

#pragma mark Tree

- (void)setParentWebEditorItem:(SVWebEditorItem *)item
{
    [super setParentWebEditorItem:item];
    //[self setHTMLContext:[item HTMLContext]];  Not really helpful since root item has no context
}

#pragma mark Content

- (id)initWithContentObject:(SVContentObject *)contentObject
              inDOMDocument:(DOMDocument *)document;
{
    // See header for what steps are
    
    //  1)
    self = [self init];
    
    //  2)
    [self setRepresentedObject:contentObject];
    
    //  3)
    [self loadHTMLElementFromDocument:document];
    OBASSERT([self HTMLElement]);
    
    
    return self;
}

- (void)createHTMLElement
{
    // Gather the HTML
    NSMutableString *htmlString = [[NSMutableString alloc] init];
    
    SVHTMLContext *context = [[[[self HTMLContext] class] alloc] initWithStringWriter:htmlString];
    [context copyPropertiesFromContext:[self HTMLContext]];
    
    [context push];
    [self writeRepresentedObjectHTML];
    [context pop];
    [context release];
    
    
    // Create DOM objects from HTML
    DOMDocumentFragment *fragment = [[self HTMLDocument]
                                     createDocumentFragmentWithMarkupString:htmlString
                                     baseURL:[[self HTMLContext] baseURL]];
    [htmlString release];
    
    DOMHTMLElement *element = [fragment firstChildOfClass:[DOMHTMLElement class]];  OBASSERT(element);
    [self setHTMLElement:element];
}

- (void)loadHTMLElementFromDocument:(DOMDocument *)document;
{
    SVContentObject *contentObject = [self representedObject];
    DOMHTMLElement *element = [contentObject elementForEditingInDOMDocument:document];
    
    if (![contentObject shouldPublishEditingElementID]) [element setIdName:nil];
    
    [self setHTMLElement:element];
}

- (void)writeRepresentedObjectHTML;
{
    [[self representedObject] writeHTML:[SVHTMLContext currentContext]];
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
    WEKWebEditorView *webEditor = [self webEditor];
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

- (BOOL)isSelectable { return NO; }
- (BOOL)isEditable { return YES; }

#pragma mark Drag Source

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal;
{
    NSDragOperation result = [super draggingSourceOperationMaskForLocal:isLocal];
    
    if (isLocal && [self parentWebEditorItem] == [[self HTMLContext] sidebarDOMController])
    {
        result = result | NSDragOperationMove;
    }
    
    return result;
}

@end


#pragma mark -


@implementation SVContentObject (SVDOMController)

- (Class)DOMControllerClass;
{
    return [SVDOMController class];
}

@end


#pragma mark -


@implementation SVWebEditorItem (SVDOMController)

#pragma mark Content

- (void)loadHTMLElementFromDocument:(DOMDocument *)document; { }

#pragma mark Updating

- (void)update; { }

- (void)updateIfNeeded; // recurses down the tree
{
    // The update may well have meant no children need updating any more. If so, no biggie as this recursion should do nothing
    [[self childWebEditorItems] makeObjectsPerformSelector:_cmd];
}

- (SVWebEditorHTMLContext *)HTMLContext { return nil; }

#pragma mark Drag & Drop

- (SVWebEditorItem *)hitTestDOMNode:(DOMNode *)node
                       draggingInfo:(id <NSDraggingInfo>)info;
{
    // Dive down to next item
    SVWebEditorItem *result = [[self childItemForDOMNode:node] hitTestDOMNode:node
                                                                 draggingInfo:info];
    return result;
}

#pragma mark WebEditorViewController

- (SVWebEditorViewController *)webEditorViewController;
{
    SVWebEditorViewController *result = (id)[[self webEditor] dataSource];
    if (result) OBASSERT([result isKindOfClass:[SVWebEditorViewController class]]);
    return result;
}

@end

