//
//  SVWebEditorHTMLContext.m
//  Sandvox
//
//  Created by Mike on 05/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorHTMLContext.h"

#import "SVBodyTextDOMController.h"
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
    
    return self;
}

- (void)dealloc
{
    [_items release];
    [_objectKeyPathPairs release];
    
    [super dealloc];
}

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
    
    if ([value isKindOfClass:[SVTitleBox class]])
    {
        // Copy basic properties from text block
        result = [[SVTextFieldDOMController alloc] init];
        [result setRepresentedObject:value];
        [result setHTMLContext:self];
        [result setRichText:[aTextBlock isRichText]];
        [result setFieldEditor:[aTextBlock isFieldEditor]];
        
        // Bind to model
        [result bind:NSValueBinding
            toObject:value
         withKeyPath:@"textHTMLString"
             options:nil];
    }
    else if ([value isKindOfClass:[SVRichText class]])
    {
        result = [[SVBodyTextDOMController alloc] init];
        [result setRepresentedObject:value];
        [result setHTMLContext:self];
        [result setRichText:YES];
        [result setFieldEditor:NO];
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

@end


#pragma mark -


@implementation SVHTMLContext (SVEditing)

- (void)willBeginWritingHTMLTextBlock:(SVHTMLTextBlock *)textBlock; { }
- (void)didEndWritingHTMLTextBlock; { }

- (void)willBeginWritingObjectWithDOMController:(SVDOMController *)controller; { }

@end

