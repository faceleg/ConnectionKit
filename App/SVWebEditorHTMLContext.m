//
//  SVWebEditorHTMLContext.m
//  Sandvox
//
//  Created by Mike on 05/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorHTMLContext.h"

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
- (void)finishWithCurrentItem;
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

- (void)close;
{
    [super close];
    
    // Also ditch controllers
    [_DOMControllers release]; _DOMControllers = nil;
    [_dependencies release]; _dependencies = nil;
    [_media release]; _media = nil;
}

- (void)dealloc
{
    [_sidebarPageletsController release];
    
    [super dealloc];
    OBASSERT(!_DOMControllers);
    OBASSERT(!_dependencies);
    OBASSERT(!_media);
}

#pragma mark Purpose

- (KTHTMLGenerationPurpose)generationPurpose; { return kSVHTMLGenerationPurposeEditing; }

#pragma mark DOM Controllers

- (NSArray *)DOMControllers;
{
    return [[_DOMControllers copy] autorelease];
}

- (void)beginDOMController:(SVDOMController *)controller; // call one of the -didEndWriting… methods after
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
    
    [controller awakeFromHTMLContext:self];
}

- (void)addDOMController:(SVDOMController *)controller;
{
    [self beginDOMController:controller];
    [self finishWithCurrentItem];
}

- (SVDOMController *)currentDOMController; { return _currentDOMController; }

- (void)finishWithCurrentItem;
{
    _currentDOMController = (SVDOMController *)[_currentDOMController parentWebEditorItem];
}

#pragma mark Graphics

- (void)willBeginWritingGraphic:(SVGraphic *)object
{
    [super willBeginWritingGraphic:object];
    
    SVDOMController *controller = [object newDOMController];
    [self beginDOMController:controller];
    [controller release];
}

- (void)didEndWritingGraphic;
{
    [self finishWithCurrentItem];
    
    [super didEndWritingGraphic];
}

- (void)beginCalloutWithAlignmentClassName:(NSString *)alignment;
{
    SVCalloutDOMController *controller = [[SVCalloutDOMController alloc] init];
    [self beginDOMController:controller];
    [controller release];

    [super beginCalloutWithAlignmentClassName:alignment];
}

- (void)endCallout;
{
    [super endCallout];
    
    [self finishWithCurrentItem];
}

#pragma mark Text Blocks

- (void)willBeginWritingHTMLTextBlock:(SVHTMLTextBlock *)textBlock;
{
    [super willBeginWritingHTMLTextBlock:textBlock];
    
    // Create controller
    SVDOMController *controller = [textBlock newDOMController];
    [self beginDOMController:controller];
    [controller release];
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
    [self beginDOMController:controller];    
    
    
    // Finish up
    [controller release];
}

@synthesize sidebarPageletsController = _sidebarPageletsController;
- (NSArrayController *)cachedSidebarPageletsController; { return [self sidebarPageletsController]; }

#pragma mark View Controller

@synthesize webEditorViewController = _viewController;

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

