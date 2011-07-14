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

- (SVElementInfo *)currentElement;
{
    SVElementInfo *result = _earlyElement;
    if (!result) result = [_openElementInfos lastObject];
    return result;
}

- (void)willStartElement:(NSString *)element;
{
    // Let superclasses queue up any last minute stuff as they like
    [super willStartElement:element];
    
    
    // Stash a copy of the element
    if (_openElementInfos)
    {
        SVElementInfo *info;
        if (_earlyElement)
        {
            info = _earlyElement;
            _earlyElement = nil;
        }
        else
        {
            info = [[SVElementInfo alloc] init];
        }
        
        [info setAttributes:[[self currentAttributes] attributesAsDictionary]];
                
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

- (void)beginGraphicContainer:(id <SVGraphicContainer>)container;
{
    OBPRECONDITION(!_earlyElement);
    _earlyElement = [[SVElementInfo alloc] initWithGraphicContainer:container];
    
    [super beginGraphicContainer:container];
}

#pragma mark Dependencies

- (void)addDependency:(KSObjectKeyPathPair *)dependency
{
    [[self currentElement] addDependency:dependency];
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

@end


#pragma mark -


@implementation SVElementInfo

- (id)init
{
    if (self = [super init])
    {
        _subelements = [[NSMutableArray alloc] init];
        _dependencies = [[NSMutableSet alloc] init];
    }
    
    return self;
}

- (id)initWithGraphicContainer:(id <SVGraphicContainer>)container;
{
    if (self = [self init])
    {
        _graphicContainer = [container retain];
    }
    return self;
}

- (void)dealloc;
{
    [_attributes release];
    [_subelements release];
    [_graphicContainer release];
    [_dependencies release];
    
    [super dealloc];
}

@synthesize attributes = _attributes;

- (NSArray *)subelements; { return [[_subelements copy] autorelease]; }

- (void)addSubelement:(SVElementInfo *)element;
{
    [_subelements addObject:element];
}

@synthesize graphicContainer = _graphicContainer;

- (NSSet *)dependencies; { return [[_dependencies copy] autorelease]; }

- (void)addDependency:(KSObjectKeyPathPair *)dependency;
{
    [_dependencies addObject:dependency];
}

@end
