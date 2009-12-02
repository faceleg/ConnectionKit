//
//  SVWebContentItem.m
//  Sandvox
//
//  Created by Mike on 02/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebContentItem.h"


@implementation SVWebContentItem

#pragma mark Init & Dealloc

- (id)init
{
    [super init];
    
    _textAreas = [[NSMutableArray alloc] init];
    
    return self;
}

- (void)dealloc
{
    [_textAreas release];
    
    [super dealloc];
}

#pragma mark Accessors

- (NSArray *)textAreas { return [[_textAreas copy] autorelease]; }

- (void)insertObject:(SVWebEditorTextController *)textArea inTextAreasAtIndex:(NSUInteger)index;
{
    [_textAreas insertObject:textArea atIndex:index];
}

- (void)removeObjectFromTextAreasAtIndex:(NSUInteger)index;
{
    [_textAreas removeObjectAtIndex:index];
}

@synthesize editable = _editable;

@end
