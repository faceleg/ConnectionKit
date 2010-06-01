//
//  SVDOMController.m
//  Sandvox
//
//  Created by Mike on 13/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVDOMController.h"

#import "SVSidebarDOMController.h"
#import "SVTextDOMController.h"
#import "SVWebEditorViewController.h"

#import "DOMNode+Karelia.h"


@implementation SVDOMController

+ (id)DOMControllerWithGraphic:(SVGraphic *)graphic
 createHTMLElementWithDocument:(DOMHTMLDocument *)doc
                       context:(SVHTMLContext *)parentContext;
{
    // Write HTML
    NSMutableString *htmlString = [[NSMutableString alloc] init];
    
    SVWebEditorHTMLContext *context = [[[SVWebEditorHTMLContext class] alloc]
                                       initWithStringWriter:htmlString];
    
    [context copyPropertiesFromContext:parentContext];
    [graphic writeHTML:context];
    
    
    // Retrieve controller
    id result = nil;
    for (WEKWebEditorItem *aController in [context DOMControllers])
    {
        if (![aController parentWebEditorItem]) result = aController;
    }
    OBASSERT(result);
    
    [context release];
    
    
    // Create DOM objects from HTML
    DOMDocumentFragment *fragment = [doc createDocumentFragmentWithMarkupString:htmlString
                                                                        baseURL:[parentContext baseURL]];
    [htmlString release];
    
    DOMHTMLElement *element = [fragment firstChildOfClass:[DOMHTMLElement class]];  OBASSERT(element);
    [result setHTMLElement:element];
    
    
    return result;
}

#pragma mark Init & Dealloc

- (id)init;
{
    [super init];
    
    _dependencies = [[NSMutableSet alloc] init];
    
    return self;
}

- (id)initWithElementIdName:(NSString *)elementID;
{
    if (self = [self init])
    {
        _elementID = [elementID copy];
    }
    
    return self;
}

- (id)initWithContentObject:(SVContentObject *)content;
{
    // Use the object's own ID if it has one. Otherwise make up our own
    NSString *elementID = [content elementIdName];
    if (!elementID) elementID = [NSString stringWithFormat:@"%p", content];
    
    if (self = [self initWithElementIdName:elementID])
    {
        [self setRepresentedObject:content];
    }
    return self;
}

- (void)dealloc
{
    [self removeAllDependencies];
    [_dependencies release];
    
    [_elementID release];
    [_context release];
    
    [super dealloc];
}

#pragma mark Tree

- (void)setParentWebEditorItem:(WEKWebEditorItem *)item
{
    [super setParentWebEditorItem:item];
    //[self setHTMLContext:[item HTMLContext]];  Not really helpful since root item has no context
}

#pragma mark Content

- (void)createHTMLElement
{
    // Gather the HTML
    NSMutableString *htmlString = [[NSMutableString alloc] init];
    
    SVWebEditorHTMLContext *context = [[[SVWebEditorHTMLContext class] alloc]
                                       initWithStringWriter:htmlString];
    [context copyPropertiesFromContext:[self HTMLContext]];
    
    [context push];
    [self writeRepresentedObjectHTML];
    [context pop];
    
    
    // Create DOM objects from HTML
    DOMDocumentFragment *fragment = [[self HTMLDocument]
                                     createDocumentFragmentWithMarkupString:htmlString
                                     baseURL:[[self HTMLContext] baseURL]];
    [htmlString release];
    
    DOMHTMLElement *element = [fragment firstChildOfClass:[DOMHTMLElement class]];  OBASSERT(element);
    [self setHTMLElement:element];
    
    
    // Insert controllers
    for (WEKWebEditorItem *aController in [context DOMControllers])
    {
        WEKWebEditorItem *parent = [aController parentWebEditorItem];
        if (parent && ![parent parentWebEditorItem])
        {
            [self addChildWebEditorItem:aController];
        }
    }
    [context release];
}

- (void)loadHTMLElementFromDocument:(DOMDocument *)document;
{
    DOMHTMLElement *element = (DOMHTMLElement *)[document getElementById:[self elementIdName]];
    
    if (![[self representedObject] shouldPublishEditingElementID]) [element setIdName:nil];
    
    [self setHTMLElement:element];
}

@synthesize elementIdName = _elementID;

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

- (void)updateToReflectSelection;
{
    [super updateToReflectSelection];
    
    // Turn off editing for enclosing text temporarily. #75840
    // It's a little hacky, but works!
    SVTextDOMController *textController = [self textDOMController];
    if ([self isEditing])
    {
        [[textController textHTMLElement] removeAttribute:@"contenteditable"];
    }
    else
    {
        [textController setEditable:[textController isEditable]];
    }
}

#pragma mark Update Scheduling

@synthesize needsUpdate = _needsUpdate;

- (void)setNeedsUpdate;
{
    // By default, controllers don't know how to update, so must update parent instead
    if ([self methodForSelector:@selector(update)] == 
        [SVDOMController instanceMethodForSelector:@selector(update)])
    {
        return [super setNeedsUpdate];
    }
    
    
    // Try to get hold of the controller in charge of update coalescing
	SVWebEditorViewController *controller = [[self HTMLContext] webEditorViewController];
    if ([controller respondsToSelector:@selector(scheduleUpdate)] || ![self webEditor])
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

- (NSSet *)dependencies { return [[_dependencies copy] autorelease]; }

- (void)addDependency:(KSObjectKeyPathPair *)pair;
{
    OBASSERT(_dependencies);
    
    // Ignore parser properties
    if (![[pair object] isKindOfClass:[SVTemplateParser class]])
    {
        if (![_dependencies containsObject:pair])
        {
            [_dependencies addObject:pair];
            
            [[pair object] addObserver:self
                            forKeyPath:[pair keyPath]
                               options:0
                               context:sWebViewDependenciesObservationContext];
        }
    }
}

- (void)removeAllDependencies;
{
    for (KSObjectKeyPathPair *aDependency in [self dependencies])
    {
        [[aDependency object] removeObserver:self forKeyPath:[aDependency keyPath]];
    }
    
    [_dependencies removeAllObjects];
}

#pragma mark Editing

- (BOOL)isSelectable { return NO; }
- (BOOL)isEditable { return YES; }

#pragma mark Sidebar

- (BOOL)isSidebarPageletDOMController;
{
    return [[self parentWebEditorItem] isKindOfClass:[SVSidebarDOMController class]];
}

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal;
{
    NSDragOperation result = [super draggingSourceOperationMaskForLocal:isLocal];
    
    if (isLocal && (!(result & NSDragOperationMove) || !(result & NSDragOperationGeneric)))
    {
        if ([self isSidebarPageletDOMController] || [self textDOMController])
        {
            result = result | NSDragOperationMove | NSDragOperationGeneric;
        }
    }
    
    return result;
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == sWebViewDependenciesObservationContext)
    {
        [self setNeedsUpdate];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end


#pragma mark -


@implementation SVContentObject (SVDOMController)

- (SVDOMController *)newDOMController;
{
    return [[SVDOMController alloc] initWithContentObject:self];
}

@end


#pragma mark -


@implementation WEKWebEditorItem (SVDOMController)

#pragma mark Content

- (void)loadHTMLElementFromDocument:(DOMDocument *)document; { }

#pragma mark Updating

- (void)update; { }

- (void)setNeedsUpdate;
{
    SVWebEditorViewController *controller = [[self HTMLContext] webEditorViewController];
    if ([controller respondsToSelector:_cmd])
    {
        [controller performSelector:_cmd];
    }
}

- (void)updateIfNeeded; // recurses down the tree
{
    // The update may well have meant no children need updating any more. If so, no biggie as this recursion should do nothing
    [[self childWebEditorItems] makeObjectsPerformSelector:_cmd];
}

- (SVWebEditorHTMLContext *)HTMLContext { return nil; }

#pragma mark Drag & Drop

- (NSArray *)registeredDraggedTypes; { return nil; }

- (WEKWebEditorItem *)hitTestDOMNode:(DOMNode *)node
                       draggingInfo:(id <NSDraggingInfo>)info;
{
    OBPRECONDITION(node);
    
    WEKWebEditorItem *result = nil;
    
    if ([node isDescendantOfNode:[self HTMLElement]] || ![self HTMLElement])
    {
        for (WEKWebEditorItem *anItem in [self childWebEditorItems])
        {
            result = [anItem hitTestDOMNode:node draggingInfo:info];
            if (result) break;
        }
        
        if (!result)
        {
            NSArray *types = [self registeredDraggedTypes];
            if ([[info draggingPasteboard] availableTypeFromArray:types]) result = self;
        }
    }
    
    return result;
}

@end

