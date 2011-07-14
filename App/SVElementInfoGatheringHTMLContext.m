//
//  SVElementInfoGatheringHTMLContext.m
//  Sandvox
//
//  Created by Mike on 07/07/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVElementInfoGatheringHTMLContext.h"

#import "SVDOMController.h"
#import "SVGraphic.h"


@implementation SVElementInfoGatheringHTMLContext

- (id)initWithOutputWriter:(id <KSWriter>)output;
{
    if (self = [super initWithOutputWriter:output])
    {
        _topLevelElements = [[NSMutableArray alloc] init];
        _openElementInfos = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void)close;
{
    [super close];
    
    [_openElementInfos release]; _openElementInfos = nil;   // so more can't be added
}

- (void)dealloc;
{
    [_topLevelElements release];
    // _openElementInfos is handled by super calling through to -close
    
    [super dealloc];
}

#pragma mark Elements

- (NSArray *)topLevelElements; { return [[_topLevelElements copy] autorelease]; }
- (SVElementInfo *)currentElement; { return [_openElementInfos lastObject]; }

- (void)willStartElement:(NSString *)element;
{
    // Let superclasses queue up any last minute stuff as they like
    [super willStartElement:element];
    
    
    // Stash a copy of the element
    if (_openElementInfos)
    {
        SVElementInfo *info = [[SVElementInfo alloc] init];
        [info setAttributes:[[self currentAttributes] attributesAsDictionary]];
        [info setGraphicContainer:[self currentGraphicContainer]];
        
        [[self currentElement] addSubelement:info];
        [_openElementInfos addObject:info];
        if ([_openElementInfos count] == 1) [_topLevelElements addObject:info];
        
        [info release];
    }
}

- (void)endElement
{
    [super endElement];
    [_openElementInfos removeLastObject];
}

#pragma mark DOM Controllers

- (void)addDOMControllersForElement:(SVElementInfo *)element toMutableArray:(NSMutableArray *)result;
{
    id <SVGraphicContainer> container = [element graphicContainer];
    if (container)
    {
        SVDOMController *controller = [container newDOMController];
        [result addObject:controller];
        
        // Step on down to its children
        NSMutableArray *childControllers = [[NSMutableArray alloc] init];
        for (SVElementInfo *anElement in [element subelements])
        {
            [self addDOMControllersForElement:anElement toMutableArray:childControllers];
        }
        
        for (SVDOMController *aController in childControllers)
        {
            [controller addChildWebEditorItem:aController];
        }
        
        [childControllers release];
        [controller release];
    }
    else
    {
        // Step on down to child elements
        for (SVElementInfo *anElement in [element subelements])
        {
            [self addDOMControllersForElement:anElement toMutableArray:result];
        }
    }
}

- (NSArray *)makeDOMControllers;
{
    NSMutableArray *result = [NSMutableArray array];
    for (SVElementInfo *anElement in [self topLevelElements])
    {
        [self addDOMControllersForElement:anElement toMutableArray:result];
    }
    
    return result;
}

@end


#pragma mark -


@implementation SVElementInfo

- (id)init
{
    if (self = [super init])
    {
        _subelements = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void)dealloc;
{
    [_attributes release];
    [_subelements release];
    [_graphicContainer release];
    
    [super dealloc];
}

@synthesize attributes = _attributes;

- (NSArray *)subelements; { return [[_subelements copy] autorelease]; }

- (void)addSubelement:(SVElementInfo *)element;
{
    [_subelements addObject:element];
}

@synthesize graphicContainer = _graphicContainer;

@end
