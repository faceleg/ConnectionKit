//
//  SVWebEditorHTMLContext.m
//  Sandvox
//
//  Created by Mike on 05/11/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVWebEditorHTMLContext.h"

#import "SVApplicationController.h"
#import "SVCalloutDOMController.h"
#import "SVContentDOMController.h"
#import "SVGraphicDOMController.h"
#import "SVHTMLTemplateParser.h"
#import "SVHTMLTextBlock.h"
#import "SVMediaDOMController.h"
#import "SVMediaPlugIn.h"
#import "SVMediaRequest.h"
#import "SVIndexDOMController.h"
#import "KTPage.h"
#import "SVRichText.h"
#import "SVSidebarDOMController.h"
#import "SVSummaryDOMController.h"
#import "SVTemplateParser.h"
#import "SVTextBox.h"
#import "SVTextFieldDOMController.h"
#import "SVTitleBox.h"

#import "NSIndexPath+Karelia.h"
#import "KSObjectKeyPathPair.h"


@interface SVWebEditorHTMLContext ()
- (void)endDOMController;
@end



#pragma mark -


@implementation SVWebEditorHTMLContext

#pragma mark Init & Dealloc

- (id)initWithOutputWriter:(id <KSWriter>)stream	// designated initializer
{
    [super initWithOutputWriter:stream];
    
    [self reset];
    _media = [[NSMutableSet alloc] init];
    _mediaByData = [[NSMutableDictionary alloc] init];
        
    return self;
}

- (void)dealloc
{
    [_DOMControllerPoints release];
    
    [super dealloc];
}

#pragma mark Status

- (void)reset;
{
    [super reset];
    
    
    [_rootController release];
    _currentDOMController = _rootController = [[SVContentDOMController alloc] init];
    
    [_DOMControllerPoints release]; _DOMControllerPoints = [[NSIndexPath alloc] init];
    
    [[self rootDOMController] awakeFromHTMLContext:self];   // so it stores ref to us
    
    [_media removeAllObjects];
    [_mediaByData removeAllObjects];
}

- (void)close;
{
    [super close];
    
    // Also ditch controllers
    while ([self currentDOMController] && [self currentDOMController] != [self rootDOMController]) // #98822
    {
        [self endDOMController];
    }
    
    _currentDOMController = nil;
    [_rootController release]; _rootController = nil;
    
    // Ditch media
    [_media release]; _media = nil;
    [_mediaByData release]; _mediaByData = nil;
}

#pragma mark Page

- (void)writeDocumentWithPage:(KTPage *)page;
{
	// This is a dependency only in the Web Editor, so don't register for all contexts
    [self addDependencyOnObject:[NSUserDefaultsController sharedUserDefaultsController]
                        keyPath:[@"values." stringByAppendingString:kSVLiveDataFeedsKey]];

    [super writeDocumentWithPage:page];
}

#pragma mark Purpose

- (KTHTMLGenerationPurpose)generationPurpose; { return kSVHTMLGenerationPurposeEditing; }

#pragma mark DOM Controllers

@synthesize rootDOMController = _rootController;

- (SVDOMController *)currentDOMController; { return _currentDOMController; }

- (void)startDOMController:(SVDOMController *)controller; // call one of the -didEndWriting… methods after
{
    OBPRECONDITION(controller);
    OBPRECONDITION(_currentDOMController);
    
    [_currentDOMController addChildWebEditorItem:controller];
    
    // Record the start. When open elements count gets back to its present value, current controller will be automatically ended
    _currentDOMController = controller;
    
    [_DOMControllerPoints autorelease];
    _DOMControllerPoints = [[_DOMControllerPoints indexPathByAddingIndex:[self openElementsCount]] copy];
}

- (void)endDOMController;
{
    // Adjust controller stack back up to parent controller
    
    SVDOMController *controller = _currentDOMController;
    _currentDOMController = (SVDOMController *)[_currentDOMController parentWebEditorItem];
    
    [_DOMControllerPoints autorelease];
    _DOMControllerPoints = [[_DOMControllerPoints indexPathByRemovingLastIndex] copy];
    
    [controller awakeFromHTMLContext:self];
}

- (void)popElement;
{
    [super popElement];
    
    // End current DOM Controller if appropriate
    NSInteger index = [_DOMControllerPoints lastIndex];
    if (index == [self openElementsCount])
    {
        SVDOMController *controller = [self currentDOMController];
        [self endDOMController];
        
        // Does this controller share the same element as its parent? If so, close the parent too
        if ([controller hasElementIdName])
        {
            while ([_DOMControllerPoints lastIndex] == [self openElementsCount] &&
                   [[self currentDOMController] hasElementIdName] &&
                   [[[self currentDOMController] elementIdName] isEqualToString:[controller elementIdName]])
            {
                [self endDOMController];
            }
        }
    }
}

- (void)addDOMController:(SVDOMController *)controller;
{
    [self startDOMController:controller];
    [self endDOMController];
}

#pragma mark Graphics

- (void)writeCalloutWithGraphics:(NSArray *)pagelets;
{
    // Make a controller for the callout. Will be auto-closed
    SVCalloutDOMController *controller = [[SVCalloutDOMController alloc] init];
    [self startDOMController:controller];
    [controller release];
    
    [super writeCalloutWithGraphics:pagelets];
}

- (void)writeGraphic:(id <SVGraphic, SVDOMControllerRepresentedObject>)graphic;
{
    OBPRECONDITION(graphic);
    
    
    // Special case, want to write the body of the graphic
    if (graphic == [self currentGraphicContainer])
    {
        if ([graphic respondsToSelector:@selector(newBodyDOMController)] &&
             ![graphic isKindOfClass:[SVMediaGraphic class]])
        {
            SVDOMController *controller = [(SVGraphic *)graphic newBodyDOMController];
            [self startDOMController:controller];
            [controller release];
        }
        
        return [super writeGraphic:graphic];
    }
    
    
    // Create controller for the graphic
    SVDOMController *controller = [graphic newDOMController];
    [self startDOMController:controller];
    [controller release];
    
    
    if ([graphic isPagelet])
    {
        // Pagelets are using a HTML template, so context can't track them properly. By using the private element stack API, can maniuplate for the desired result
        [self pushElement:@"pagelet"];
        [super writeGraphic:graphic];
        [self popElement];
    }
    else
    {
        [super writeGraphic:graphic];
    }
}

#pragma mark Metrics

- (void)buildAttributesForResizableElement:(NSString *)elementName object:(NSObject *)object DOMControllerClass:(Class)controllerClass sizeDelta:(NSSize)sizeDelta options:(SVResizingOptions)options;
{
    // Figure out a decent controller class
    if (!controllerClass) 
    {
        if ([object isKindOfClass:[SVMediaPlugIn class]])
        {
            controllerClass = [SVMediaDOMController class];
        }
        else
        {
            controllerClass = [SVResizableDOMController class];
        }
    }
    
    
    // 
    SVResizableDOMController *controller = [[controllerClass alloc] initWithRepresentedObject:
                                              [[self currentDOMController] representedObject]];
    [controller setSizeDelta:sizeDelta];
    [controller setResizeOptions:options];
    
    
    // Has an ID for the controller already been decided?
    KSElementInfo *info = [self currentElementInfo];
    NSString *ID = [[info attributesAsDictionary] objectForKey:@"id"];
    if (ID)
    {
        [controller setElementIdName:ID];
    }
    
    
    [self startDOMController:controller];
    [controller release];
    
    [super buildAttributesForResizableElement:elementName object:object DOMControllerClass:controllerClass sizeDelta:sizeDelta options:options];
}

#pragma mark Text Blocks

- (void)willBeginWritingHTMLTextBlock:(SVHTMLTextBlock *)textBlock;
{
    [super willBeginWritingHTMLTextBlock:textBlock];
    
    // Create controller
    SVDOMController *controller = [textBlock newDOMController];
    [self startDOMController:controller];
    [controller release];
}

- (void)writeElement:(NSString *)elementName
     withTitleOfPage:(id <SVPage>)page
         asPlainText:(BOOL)plainText
          attributes:(NSDictionary *)attributes;
{
    // Create text-block
    SVHTMLTextBlock *textBlock = [[SVHTMLTextBlock alloc] init];
    [textBlock setEditable:NO];
    [textBlock setTagName:elementName];
    [textBlock setHTMLSourceObject:page];
    [textBlock setHTMLSourceKeyPath:@"title"];
    
    
    // Create controller
    [self willBeginWritingHTMLTextBlock:textBlock];
    [textBlock release];
    
    [super writeElement:elementName withTitleOfPage:page asPlainText:plainText attributes:attributes];

    
    [self didEndWritingHTMLTextBlock];
}

- (void)willWriteSummaryOfPage:(SVSiteItem *)page;
{
    // Generate DOM controller for it
    SVSummaryDOMController *controller = [[SVSummaryDOMController alloc] init];
    [controller setItemToSummarize:page];
    
    [self startDOMController:controller];
    [controller release];
    
    [super willWriteSummaryOfPage:page];
}

#pragma mark Dependencies

- (void)addDependency:(KSObjectKeyPathPair *)dependency;
{
    // Ignore parser properties. And now context too
    // I think my original reason is that those properties aren't really going to change, but we're interested in depending on the original source of that property. e.g. reload when user turns on/off live data feeds, but do so with a fresh context
    if ([[dependency object] isKindOfClass:[SVTemplateParser class]] ||
        [[dependency keyPath] hasPrefix:@"currentContext."])
    {
        return;
    }
    
    
    [[self currentDOMController] addDependency:dependency];
}

- (void)addDependencyOnObject:(NSObject *)object keyPath:(NSString *)keyPath;
{
    // Trying to observe next/previous page's title with a compound keypath is a bad idea. #102968
    if ([object isKindOfClass:[KTPage class]])
    {
        if ([keyPath hasPrefix:@"nextPage."])
        {
            object = [object valueForKey:@"nextPage"];
            keyPath = [keyPath substringFromIndex:[@"nextPage." length]];
        }
        else if ([keyPath hasPrefix:@"previousPage."])
        {
            object = [object valueForKey:@"previousPage"];
            keyPath = [keyPath substringFromIndex:[@"previousPage." length]];
        }
    }
    
    
    
    [super addDependencyOnObject:object keyPath:keyPath];
    
    
    KSObjectKeyPathPair *pair = [[KSObjectKeyPathPair alloc] initWithObject:object
                                                                    keyPath:keyPath];
    [self addDependency:pair];
    [pair release];
}

#pragma mark Media

- (NSSet *)media; { return [[_media copy] autorelease]; }

- (NSURL *)addMediaWithRequest:(SVMediaRequest *)request;
{
    NSURL *result = nil;
    
    SVMedia *media = [request media];
    NSData *data = [media mediaData];
    
    if (data)
    {
        SVMedia *matchingMedia = [_mediaByData objectForKey:data];
        if (matchingMedia)
        {
            media = matchingMedia;
        }
        else
        {
            [_mediaByData setObject:media forKey:data];
        }
    }
    
    result = [super addMediaWithRequest:request];
    [_media addObject:media];
    
    return result;
}

#pragma mark Sidebar

- (void)startSidebar:(SVSidebar *)sidebar;
{
    // Create controller
    SVSidebarDOMController *controller = [[SVSidebarDOMController alloc]
                                          initWithPageletsController:[self sidebarPageletsController]];
    
    [controller setRepresentedObject:sidebar];
    
    // Store controller
    [self startDOMController:controller];    
    
    
    [super startSidebar:sidebar];
    
    // Finish up
    [controller release];
}

#pragma mark Element Primitives

- (void)pushAttribute:(NSString *)attribute value:(id)value;
{
    [super pushAttribute:attribute value:value];
    
    // Was this an id attribute, removing our need to write one?
    if (![[self currentDOMController] hasElementIdName] && [attribute isEqualToString:@"id"])
    {
        [[self currentDOMController] setElementIdName:value];
    }
}

- (void)startElement:(NSString *)elementName writeInline:(BOOL)writeInline; // for more control
{
    // First write an id attribute if it's needed
    // DOM Controllers need an ID so they can locate their element in the DOM. If the HTML doesn't normally contain an ID, insert it ourselves
    SVDOMController *controller = [self currentDOMController];
    if (![controller hasElementIdName])
    {
        // Invent an ID for the controller if needed
        NSString *idName = [controller elementIdName];
        if (!idName)
        {
            idName = [NSString stringWithFormat:@"%p", controller];
            [controller setElementIdName:idName];
        }
        
        [self pushAttribute:@"id" value:idName];
        OBASSERT([[self currentDOMController] hasElementIdName]);
    }
    
    [super startElement:elementName writeInline:writeInline];
}

@end


#pragma mark -


@implementation SVHTMLContext (SVEditing)

- (void)startSidebar:(SVSidebar *)sidebar;
{
    [self startElement:@"div" idName:@"sidebar-container" className:nil];
}

- (WEKWebEditorItem *)currentDOMController; { return nil; }

@end



#pragma mark -


@implementation SVDOMController (SVWebEditorHTMLContext)

- (void)awakeFromHTMLContext:(SVWebEditorHTMLContext *)context;
{
    [self setHTMLContext:context];
}

@end



#pragma mark -


@implementation WEKWebEditorItem (SVWebEditorHTMLContext)

- (void)awakeFromHTMLContext:(SVWebEditorHTMLContext *)context; { }

@end

