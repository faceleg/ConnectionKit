//
//  SVWebEditorHTMLContext.m
//  Sandvox
//
//  Created by Mike on 05/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorHTMLContext.h"

#import "SVDOMController.h"
#import "SVTemplateParser.h"

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

- (void)addItem:(SVWebEditorItem *)item
{
    [_items addObject:item];
    
    [_currentItem addChildWebEditorItem:item];
    _currentItem = item;
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
    [self addItem:controller];
    
    // Finish up
    [controller release];
}

- (void)didEndWritingGraphic;
{
    [self finishWithCurrentItem];
    
    [super didEndWritingGraphic];
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
