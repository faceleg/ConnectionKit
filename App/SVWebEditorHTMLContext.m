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
#import "SVHTMLTextBlock.h"
#import "SVRichText.h"
#import "SVTemplateParser.h"
#import "SVTextFieldDOMController.h"
#import "SVTitleBox.h"

#import "KSObjectKeyPathPair.h"


@implementation SVWebEditorHTMLContext

- (id)initWithStringWriter:(id <KSStringWriter>)stream
{
    [super initWithStringWriter:stream];
    
    _items = [[NSMutableArray alloc] init];
    _objectKeyPathPairs = [[NSMutableSet alloc] init];
    _media = [[NSMutableSet alloc] init];
    _sidebarPageletDOMControllers = [[NSMutableArray alloc] init];
    
    return self;
}

- (void)dealloc
{
    [_items release];
    [_objectKeyPathPairs release];
    [_media release];
    [_sidebarPageletDOMControllers release];
    [_sidebarPageletsController release];
    
    [super dealloc];
}

#pragma mark Purpose

- (KTHTMLGenerationPurpose)generationPurpose; { return kSVHTMLGenerationPurposeEditing; }

#pragma mark DOM Controllers

- (NSArray *)webEditorItems;
{
    return [[_items copy] autorelease];
}

- (void)finishWithCurrentItem;
{
    _currentItem = [_currentItem parentWebEditorItem];
}

- (void)willBeginWritingGraphic:(SVGraphic *)object
{
    [super willBeginWritingGraphic:object];
    
    // Create controller
    SVDOMController *controller = [[[object DOMControllerClass] alloc] init];
    [controller setRepresentedObject:object];
    
    // Store controller
    [self willBeginWritingObjectWithDOMController:controller];
    
    if ([[[self cachedSidebarPageletsController] arrangedObjects] containsObject:object])
    {
        [_sidebarPageletDOMControllers addObject:controller];
    }
    
    
    // Finish up
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
        result = [[[value DOMControllerClass] alloc] init];
        [result setRepresentedObject:value];
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

- (void)writeCalloutStartTagsWithAlignmentClassName:(NSString *)alignment;
{
    SVCalloutDOMController *controller = [[SVCalloutDOMController alloc] init];
    [self willBeginWritingObjectWithDOMController:controller];
    [controller release];
    
    // Note that SVWebEditorHTMLContext overrides this method to write slightly differently. So if you change it here, make sure to change there too if needed
    [self writeStartTag:@"div"
                 idName:[controller HTMLElementIDName]
              className:[@"callout-container " stringByAppendingString:alignment]];
    
    [self writeStartTag:@"div" idName:nil className:@"callout"];
    
    [self writeStartTag:@"div" idName:nil className:@"callout-content"];
}

- (void)writeCalloutEnd;
{
    [super writeCalloutEnd];
    
    [self finishWithCurrentItem];
}

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

- (void)willBeginWritingObjectWithDOMController:(SVDOMController *)controller;
{
    [_items addObject:controller];
    
    [_currentItem addChildWebEditorItem:controller];
    _currentItem = controller;
    
    [controller setHTMLContext:self];
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
    OBASSERT(_objectKeyPathPairs);
    
    // Ignore parser properties
    if (![[pair object] isKindOfClass:[SVTemplateParser class]])
    {
        [_objectKeyPathPairs addObject:pair];
    }
}

- (NSSet *)dependencies { return [[_objectKeyPathPairs copy] autorelease]; }

#pragma mark Media

- (NSSet *)media; { return [[_media copy] autorelease]; }

- (NSURL *)addMedia:(id <SVMedia>)media;
{
    NSURL *result = [super addMedia:media];
    [_media addObject:media];
    return result;
}

#pragma mark Sidebar

- (NSArray *)sidebarPageletDOMControllers
{
    return [[_sidebarPageletDOMControllers copy] autorelease];
}

@synthesize sidebarPageletsController = _sidebarPageletsController;
- (NSArrayController *)cachedSidebarPageletsController; { return [self sidebarPageletsController]; }

@end


#pragma mark -


@implementation SVHTMLContext (SVEditing)

- (void)willBeginWritingHTMLTextBlock:(SVHTMLTextBlock *)textBlock; { }
- (void)didEndWritingHTMLTextBlock; { }

- (void)willBeginWritingObjectWithDOMController:(SVDOMController *)controller; { }

- (NSArrayController *)cachedSidebarPageletsController; { return nil; }

@end

