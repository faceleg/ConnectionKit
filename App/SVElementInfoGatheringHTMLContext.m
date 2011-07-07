//
//  SVElementInfoGatheringHTMLContext.m
//  Sandvox
//
//  Created by Mike on 07/07/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVElementInfoGatheringHTMLContext.h"


@implementation SVElementInfoGatheringHTMLContext

- (id) initWithOutputWriter:(id <KSWriter>)output;
{
    if (self = [super initWithOutputWriter:output])
    {
        _openElementInfo = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void)dealloc;
{
    [_openElementInfo release];
    [super dealloc];
}

#pragma mark Elements

- (SVElementInfo *)rootElement; { return [_openElementInfo objectAtIndex:0]; }
- (SVElementInfo *)currentElement; { return [_openElementInfo lastObject]; }

- (void)willStartElement:(NSString *)element;
{
    // Let superclasses queue up any last minute stuff as they like
    [super willStartElement:element];
    
    
    // Stash a copy of the element
    SVElementInfo *info = [[SVElementInfo alloc] initWithElementInfo:[self currentElementInfo]];
    [info setName:element];
    
    [[self currentElement] addSubelement:info];
    [_openElementInfo addObject:info];
    [info release];
}

- (void)endElement
{
    [super endElement];
    [_openElementInfo removeLastObject];
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
    [_subelements release];
    [super dealloc];
}

- (NSArray *)subelements; { return [[_subelements copy] autorelease]; }

- (void)addSubelement:(KSElementInfo *)element;
{
    [_subelements addObject:element];
}

@end
