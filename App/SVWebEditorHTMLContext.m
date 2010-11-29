//
//  SVWebEditorHTMLContext.m
//  Sandvox
//
//  Created by Mike on 05/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorHTMLContext.h"

#import "SVApplicationController.h"
#import "SVCalloutDOMController.h"
#import "SVContentDOMController.h"
#import "SVGraphicDOMController.h"
#import "SVHTMLTemplateParser.h"
#import "SVHTMLTextBlock.h"
#import "SVImageDOMController.h"
#import "SVIndexDOMController.h"
#import "SVMediaPlugIn.h"
#import "SVRichText.h"
#import "SVSidebarDOMController.h"
#import "SVSummaryDOMController.h"
#import "SVTemplateParser.h"
#import "SVTextFieldDOMController.h"
#import "SVTitleBox.h"

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
        
    return self;
}

- (id)initWithOutputWriter:(id <KSWriter>)output inheritFromContext:(SVHTMLContext *)context;
{
    self = [super initWithOutputWriter:output inheritFromContext:context];
    
    [self setSidebarPageletsController:[context cachedSidebarPageletsController]];
    
    return self;
}

- (void)dealloc
{
    [_sidebarPageletsController release];
    
    [super dealloc];
    OBASSERT(!_rootController);
    OBASSERT(!_media);
}

#pragma mark Status

- (void)reset;
{
    [super reset];
    
    
    [_rootController release];
    _currentDOMController = _rootController = [[SVContentDOMController alloc] init];
    
    [[self rootDOMController] awakeFromHTMLContext:self];   // so it stores ref to us
    
    [_media removeAllObjects];
}

- (void)close;
{
    [super close];
    
    // Also ditch controllers
    [_rootController release]; _rootController = nil;
    [_media release]; _media = nil;
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
    [_currentDOMController addChildWebEditorItem:controller];
    
    _currentDOMController = controller;
}

- (void)endDOMController;
{
    SVDOMController *controller = _currentDOMController;
    _currentDOMController = (SVDOMController *)[_currentDOMController parentWebEditorItem];
    
    [controller awakeFromHTMLContext:self];
}

- (void)addDOMController:(SVDOMController *)controller;
{
    [self startDOMController:controller];
    [self endDOMController];
}

#pragma mark Text

- (void)writeText:(SVRichText *)text withDOMController:(SVDOMController *)controller;
{
    // Fake it and don't insert into hierarchy
    SVDOMController *currentController = _currentDOMController;
    _currentDOMController = controller;
    
    
    // Generate HTML
    [text writeHTML:self];
    
    
    // Reset
    [self endDOMController];
    _currentDOMController = currentController;
}

#pragma mark Graphics

- (void)willWriteGraphic:(SVGraphic *)graphic;
{
    // Register placement dependency early so it causes article to update, not graphic/callout
    if ([graphic textAttachment]) [self addDependencyForKeyPath:@"textAttachment.placement" ofObject:graphic];
}

- (void)writeGraphic:(SVGraphic *)graphic;
{
    OBPRECONDITION(graphic);
    [self willWriteGraphic:graphic];
    
    
    // Handle callouts specially
    if ([graphic isCallout])
    {
        // Make a controller for the callout, but only if it's not part of an existing callout
        if (![[self currentDOMController] isKindOfClass:[SVCalloutDOMController class]])
        {
            SVCalloutDOMController *controller = [[SVCalloutDOMController alloc] init];
            [self startDOMController:controller];
            [controller release];
        }
        
        // We will create a controller for the graphic shortly, after the callout opening has been written
    }
    else
    {
        // If writing a regular grapic straight after a callout, our usual cue to end the callout controller comes too later (just after the graphic controller has been started), so force it to end here instead
        if ([[self currentDOMController] isKindOfClass:[SVCalloutDOMController class]])
        {
            [self endDOMController];
        }
    }
    
    
    // Do normal writing
    [super writeGraphic:graphic];
    
    
    // if (callout) [self endDOMController];    // Don't do this, will end it lazily
}

- (void)writeGraphicIgnoringCallout:(id <SVGraphic, SVDOMControllerRepresentedObject>)graphic;
{
    // Create controller for the graphic
    SVDOMController *controller = [graphic newDOMController];
    [self startDOMController:controller];
    [controller release];
    
    [super writeGraphicIgnoringCallout:graphic];
    
    // Tidy up
    [self endDOMController];
}

- (void)writeGraphic:(SVGraphic *)graphic withDOMController:(SVGraphicDOMController *)controller;
{
    [self willWriteGraphic:graphic];
    
    
    // Fake it and don't insert into hierarchy
    SVDOMController *currentController = _currentDOMController;
    _currentDOMController = controller;
        
    
    // Generate HTML. Call super so as not to generate another controller
    [super writeGraphicIgnoringCallout:graphic];
    
    
    // Reset
    [self endDOMController];
    _currentDOMController = currentController;
}

- (void)writeGraphicBody:(id <SVGraphic>)graphic;
{
    if ([graphic isKindOfClass:[SVMediaGraphic class]])
    {
        [super writeGraphicBody:graphic];
    }
    else
    {
        SVDOMController *controller = [(SVGraphic *)graphic newBodyDOMController];
        [self startDOMController:controller];
        [controller release];

        [super writeGraphicBody:graphic];

        [self endDOMController];
    }
}

- (void)megaBufferedWriterWillFlush:(KSMegaBufferedWriter *)buffer;
{
    [super megaBufferedWriterWillFlush:buffer];
    
    // Only once the callout buffer flushes can we be sure the element ended.
    if ([[self currentDOMController] isKindOfClass:[SVCalloutDOMController class]])
    {
        [self endDOMController];
    }
}

#pragma mark Metrics

- (void)buildAttributesForElement:(NSString *)elementName bindSizeToObject:(NSObject *)object DOMControllerClass:(Class)controllerClass  sizeDelta:(NSSize)sizeDelta;
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
            controllerClass = [SVSizeBindingDOMController class];
        }
    }
    
    
    // 
    SVSizeBindingDOMController *controller = [[controllerClass alloc] initWithRepresentedObject:
                                              [[self currentDOMController] representedObject]];
    [controller setSizeDelta:sizeDelta];
    
    [self startDOMController:controller];
    _openSizeBindingControllersCount++;
    [controller release];
    
    [super buildAttributesForElement:elementName bindSizeToObject:object DOMControllerClass:controllerClass sizeDelta:sizeDelta];
}

- (void)endElement;
{
    [super endElement];
    
    if (_openSizeBindingControllersCount)
    {
        [self endDOMController];
        _openSizeBindingControllersCount--;
    }
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

- (void)didEndWritingHTMLTextBlock;
{
    [self endDOMController];
    [super didEndWritingHTMLTextBlock];
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

- (void)addDependency:(KSObjectKeyPathPair *)pair;
{
    // Ignore parser properties – why? Mike.
    if (![[pair object] isKindOfClass:[SVTemplateParser class]])
    {
        [[self currentDOMController] addDependency:pair];
    }
}

- (void)addDependencyOnObject:(NSObject *)object keyPath:(NSString *)keyPath;
{
    [super addDependencyOnObject:object keyPath:keyPath];
    
    
    KSObjectKeyPathPair *pair = [[KSObjectKeyPathPair alloc] initWithObject:object
                                                                    keyPath:keyPath];
    [self addDependency:pair];
    [pair release];
}

#pragma mark Media

- (NSSet *)media; { return [[_media copy] autorelease]; }

- (NSURL *)addMedia:(id <SVMedia>)media;
{
    NSURL *result = [super addMedia:media];
    [_media addObject:media];
    return result;
}

#pragma mark Sidebar

- (void)willBeginWritingSidebar:(SVSidebar *)sidebar;
{
    [super willBeginWritingSidebar:sidebar];
    
    // Create controller
    SVSidebarDOMController *controller = [[SVSidebarDOMController alloc]
                                          initWithPageletsController:[self sidebarPageletsController]];
    
    [controller setRepresentedObject:sidebar];
    
    // Store controller
    [self startDOMController:controller];    
    
    
    // Finish up
    [controller release];
}

@synthesize sidebarPageletsController = _sidebarPageletsController;
- (NSArrayController *)cachedSidebarPageletsController; { return [self sidebarPageletsController]; }

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

- (void)willBeginWritingHTMLTextBlock:(SVHTMLTextBlock *)sidebar; { }
- (void)didEndWritingHTMLTextBlock; { }

- (void)willBeginWritingSidebar:(SVSidebar *)sidebar; { }
- (SVSidebarPageletsController *)cachedSidebarPageletsController; { return nil; }

- (WEKWebEditorItem *)currentDOMController; { return nil; }

@end


#pragma mark -


@implementation SVGraphic (SVWebEditorHTMLContext)

// For the benefit of pagelet HTML template
- (void)writeBody
{
    SVHTMLContext *context = [[SVHTMLTemplateParser currentTemplateParser] HTMLContext];
    [context writeGraphicBody:self];
}

@end



#pragma mark -


@implementation SVDOMController (SVWebEditorHTMLContext)

- (void)awakeFromHTMLContext:(SVWebEditorHTMLContext *)context;
{
    [self setHTMLContext:context];
}

@end

