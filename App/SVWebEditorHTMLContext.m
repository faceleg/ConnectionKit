//
//  SVWebEditorHTMLContext.m
//  Sandvox
//
//  Created by Mike on 05/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorHTMLContext.h"

#import "SVRichTextDOMController.h"
#import "SVCalloutDOMController.h"
#import "SVGraphic.h"
#import "SVHTMLTextBlock.h"
#import "SVRichText.h"
#import "SVSidebarDOMController.h"
#import "SVTemplateParser.h"
#import "SVTextFieldDOMController.h"
#import "SVTitleBox.h"

#import "KSObjectKeyPathPair.h"


@interface SVWebEditorHTMLContext ()
@property(nonatomic, retain, readwrite) SVSidebarDOMController *sidebarDOMController;
@end


#pragma mark -


@implementation SVWebEditorHTMLContext

- (id)initWithStringWriter:(id <KSStringWriter>)stream
{
    [super initWithStringWriter:stream];
    
    _DOMControllers = [[NSMutableArray alloc] init];
    _dependencies = [[NSMutableSet alloc] init];
    _media = [[NSMutableSet alloc] init];
    
    return self;
}

- (void)dealloc
{
    [_DOMControllers release];
    [_dependencies release];
    [_media release];
    [_sidebarDOMController release];
    [_sidebarPageletsController release];
    
    [super dealloc];
}

#pragma mark Purpose

- (KTHTMLGenerationPurpose)generationPurpose; { return kSVHTMLGenerationPurposeEditing; }

#pragma mark DOM Controllers

- (NSArray *)DOMControllers;
{
    return [[_DOMControllers copy] autorelease];
}

- (void)finishWithCurrentItem;
{
    _currentDOMController = (SVDOMController *)[_currentDOMController parentWebEditorItem];
}

- (void)willBeginWritingGraphic:(SVGraphic *)object
{
    [super willBeginWritingGraphic:object];
    
    SVDOMController *controller = [object newDOMController];
    [self willBeginWritingObjectWithDOMController:controller];
    [controller release];
}

- (void)didEndWritingGraphic;
{
    [self finishWithCurrentItem];
    
    [super didEndWritingGraphic];
}

- (SVTextDOMController *)makeControllerForTextBlock:(SVHTMLTextBlock *)aTextBlock; 
{    
    SVTextDOMController *result = nil;
    
    
    // Use the right sort of text area
    id value = [[aTextBlock HTMLSourceObject] valueForKeyPath:[aTextBlock HTMLSourceKeyPath]];
    
    if ([value isKindOfClass:[SVContentObject class]])
    {
        // Copy basic properties from text block
        result = (SVTextDOMController *)[value newDOMController];
        [result setHTMLContext:self];
        [result setRichText:[aTextBlock isRichText]];
        [result setFieldEditor:[aTextBlock isFieldEditor]];
        
        if ([value isKindOfClass:[SVTitleBox class]])
        {
            // Bind to model
            [result bind:NSValueBinding
                toObject:value
             withKeyPath:@"textHTMLString"
                 options:nil];
        }
    }
    else
    {
        // Copy basic properties from text block
        result = [[SVTextFieldDOMController alloc] init];
        [result setHTMLContext:self];
        [result setRichText:[aTextBlock isRichText]];
        [result setFieldEditor:[aTextBlock isFieldEditor]];
        
        // Bind to model
        [result bind:NSValueBinding
            toObject:[aTextBlock HTMLSourceObject]
         withKeyPath:[aTextBlock HTMLSourceKeyPath]
             options:nil];
    }
    
    [result setTextBlock:aTextBlock];
    
    return [result autorelease];
}

- (void)beginCalloutWithAlignmentClassName:(NSString *)alignment;
{
    SVCalloutDOMController *controller = [[SVCalloutDOMController alloc] init];
    [self willBeginWritingObjectWithDOMController:controller];
    [controller release];

    [super beginCalloutWithAlignmentClassName:alignment];
}

- (void)endCallout;
{
    [super endCallout];
    
    [self finishWithCurrentItem];
}

- (void)willBeginWritingObjectWithDOMController:(SVDOMController *)controller;
{
    if (_currentDOMController)
    {
        [_currentDOMController addChildWebEditorItem:controller];
    }
    else
    {
        [_DOMControllers addObject:controller];
    }
    _currentDOMController = controller;
    
    
    [controller setHTMLContext:self];
}

- (SVDOMController *)currentItem; { return _currentDOMController; }

#pragma mark Text Blocks

- (void)willBeginWritingHTMLTextBlock:(SVHTMLTextBlock *)textBlock;
{
    [super willBeginWritingHTMLTextBlock:textBlock];
    
    // Create controller
    SVDOMController *controller = [self makeControllerForTextBlock:textBlock];
    [self willBeginWritingObjectWithDOMController:controller];
}

- (void)didEndWritingHTMLTextBlock;
{
    [self finishWithCurrentItem];
    [super didEndWritingHTMLTextBlock];
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
        if ([self currentItem])
        {
            [[self currentItem] addDependency:pair];
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
    [self willBeginWritingObjectWithDOMController:controller];
    [self setSidebarDOMController:controller];
    
    
    
    // Finish up
    [controller release];
}

@synthesize sidebarDOMController = _sidebarDOMController;

@synthesize sidebarPageletsController = _sidebarPageletsController;
- (NSArrayController *)cachedSidebarPageletsController; { return [self sidebarPageletsController]; }

@end


#pragma mark -


@implementation SVHTMLContext (SVEditing)

- (void)willBeginWritingHTMLTextBlock:(SVHTMLTextBlock *)sidebar; { }
- (void)didEndWritingHTMLTextBlock; { }

- (void)willBeginWritingSidebar:(SVSidebar *)sidebar; { }
- (NSArrayController *)cachedSidebarPageletsController; { return nil; }

- (WEKWebEditorItem *)currentItem; { return nil; }

@end

