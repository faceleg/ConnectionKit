//
//  SVWebEditorHTMLContext.m
//  Sandvox
//
//  Created by Mike on 05/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorHTMLContext.h"

#import "SVCalloutDOMController.h"
#import "SVGraphicDOMController.h"
#import "SVHTMLTextBlock.h"
#import "SVRichText.h"
#import "SVSidebarDOMController.h"
#import "SVTemplateParser.h"
#import "SVTextFieldDOMController.h"
#import "SVTitleBox.h"

#import "KSObjectKeyPathPair.h"


@interface SVWebEditorHTMLContext ()
- (void)endDOMController;
@end


#pragma mark -


@implementation SVWebEditorHTMLContext

- (id)initWithOutputWriter:(id <KSWriter>)stream
{
    [super initWithOutputWriter:stream];
    
    _currentDOMController = _rootController = [[SVDOMController alloc] init];
    _dependencies = [[NSMutableSet alloc] init];
    _media = [[NSMutableSet alloc] init];
    
    return self;
}

- (void)close;
{
    [super close];
    
    // Also ditch controllers
    [_rootController release]; _rootController = nil;
    [_dependencies release]; _dependencies = nil;
    [_media release]; _media = nil;
}

- (void)dealloc
{
    [_sidebarPageletsController release];
    
    [super dealloc];
    OBASSERT(!_rootController);
    OBASSERT(!_dependencies);
    OBASSERT(!_media);
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
    _needsToWriteElementID = YES;
    
    [controller awakeFromHTMLContext:self];
}

- (void)endDOMController;
{
    _currentDOMController = (SVDOMController *)[_currentDOMController parentWebEditorItem];
}

- (void)addDOMController:(SVDOMController *)controller;
{
    [self startDOMController:controller];
    [self endDOMController];
}

#pragma mark Graphics

- (void)writeGraphic:(SVGraphic *)graphic;
{
    // Handle callouts specially
    BOOL callout;
    if (callout = [graphic isCallout])
    {
        // Make a controller for the callout, but only if it's not part of an existing callout
        if (![self isWritingCallout])
        {
            SVCalloutDOMController *controller = [[SVCalloutDOMController alloc] init];
            [self startDOMController:controller];
            [controller release];
        }
        
        // We will create a controller for the graphic shortlt, after the callout opening has been written
    }
    else
    {
        if ([[self calloutBuffer] isBuffering]) [[self calloutBuffer] flush];
        
        // Create controller for the graphic
        SVDOMController *controller = [graphic newDOMController];
        [self startDOMController:controller];
        [controller release];
    }
    
    
    // Do normal writing
    [super writeGraphic:graphic];
    
    
    // Tidy up
    [self endDOMController];
    // if (callout) [self endDOMController];    // Don't do this, will end it lazily
}

- (void)startCalloutForGraphic:(SVGraphic *)graphic;
{
    [super startCalloutForGraphic:graphic];
    
    // Time to make a controller for the graphic
    SVDOMController *controller = [graphic newDOMController];
    [self startDOMController:controller];
    [controller release];
}

- (void)megaBufferedWriterWillFlush:(KSMegaBufferedWriter *)buffer;
{
    BOOL writingCallout = [self isWritingCallout];
    [super megaBufferedWriterWillFlush:buffer];
    
    // Only once the callout buffer flushes can we be sure the element ended.
    if (writingCallout) [self endDOMController];
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

- (void)writeTitleOfPage:(id <SVPage>)page enclosingElement:(NSString *)element attributes:(NSDictionary *)attributes;
{
    // Create text-block
    SVHTMLTextBlock *textBlock = [[SVHTMLTextBlock alloc] init];
    [textBlock setEditable:NO];
    [textBlock setTagName:element];
    [textBlock setHTMLSourceObject:page];
    [textBlock setHTMLSourceKeyPath:@"title"];
    
    
    // Create controller
    [self willBeginWritingHTMLTextBlock:textBlock];
    [textBlock release];
    
    [super writeTitleOfPage:page enclosingElement:element attributes:attributes];

    
    [self didEndWritingHTMLTextBlock];
}

#pragma mark Dependencies

- (void)addDependencyOnObject:(NSObject *)object keyPath:(NSString *)keyPath;
{
    [super addDependencyOnObject:object keyPath:keyPath];
    
    
    KSObjectKeyPathPair *pair = [[KSObjectKeyPathPair alloc] initWithObject:object
                                                                    keyPath:keyPath];
    [self addDependency:pair];
    [pair release];
}

- (void)addDependency:(KSObjectKeyPathPair *)pair;
{
    OBASSERT(_dependencies);
    
    // Ignore parser properties – why? Mike.
    if (![[pair object] isKindOfClass:[SVTemplateParser class]])
    {
        if ([self currentDOMController])
        {
            [[self currentDOMController] addDependency:pair];
        }
        else
        {
            [_dependencies addObject:pair];
        }
    }
}

- (NSSet *)dependencies { return [[_dependencies copy] autorelease]; }

#pragma mark Media

- (NSSet *)media; { return [[_media copy] autorelease]; }

- (NSURL *)addMedia:(id <SVMedia>)media
              width:(NSNumber *)width
             height:(NSNumber *)height
           fileType:(NSString *)type;
{
    NSURL *result = [super addMedia:media width:width height:height fileType:type];
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

#pragma mark View Controller

@synthesize webEditorViewController = _viewController;

#pragma mark Element Primitives

- (void)writeAttribute:(NSString *)attribute value:(NSString *)value;
{
    [super writeAttribute:attribute value:value];
    
    // Was this an id attribute, removing our need to write one?
    if (_needsToWriteElementID && [attribute isEqualToString:@"id"]) _needsToWriteElementID = NO;
}

- (void)didStartElement;
{
    // First write an id attribute if it's needed
    // DOM Controllers need an ID so they can locate their element in the DOM. If the HTML doesn't normally contain an ID, insert it ourselves
    if (_needsToWriteElementID)
    {
        NSString *elementID = [[self currentDOMController] elementIdName];
        if (elementID)
        {
            [self writeAttribute:@"id" value:elementID];
            OBASSERT(!_needsToWriteElementID);
        }
        else
        {
            _needsToWriteElementID = NO;
        }
    }
    
    [super didStartElement];
}

@end


#pragma mark -


@implementation SVHTMLContext (SVEditing)

- (void)willBeginWritingHTMLTextBlock:(SVHTMLTextBlock *)sidebar; { }
- (void)didEndWritingHTMLTextBlock; { }

- (void)willBeginWritingSidebar:(SVSidebar *)sidebar; { }
- (NSArrayController *)cachedSidebarPageletsController; { return nil; }

- (WEKWebEditorItem *)currentDOMController; { return nil; }

@end


#pragma mark -


@implementation SVDOMController (SVWebEditorHTMLContext)

- (void)awakeFromHTMLContext:(SVWebEditorHTMLContext *)context;
{
    [self setHTMLContext:context];
}

@end

