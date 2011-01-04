//
//  SVImageItem.m
//  Sandvox
//
//  Created by Mike on 04/11/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVImageItem.h"


@implementation SVImageItem

- (id)initWithImageRepresentation:(id)rep type:(NSString *)repType;
{
    [self init];
    
    _rep = [rep retain];
    _repType = [repType copy];
    
    return self;
}

- (id)initWithIMBImageItem:(id <IMBImageItem>)item;
{
    self = [self initWithImageRepresentation:[item imageRepresentation] type:[item imageRepresentationType]];
    
    _sourceItem = [item retain];
    
    return self;
}

- (void)dealloc
{
    [_rep release];
    [_repType release];
    [_sourceItem release];
    
    [super dealloc];
}

- (id)imageRepresentation; { return _rep; }
- (NSString *)imageRepresentationType; { return _repType; }

@synthesize originalItem = _sourceItem;

- (BOOL)isEqualToIMBImageItem:(id <IMBImageItem>)anItem;
{
    return ([[self imageRepresentationType] isEqualToString:[anItem imageRepresentationType]] &&
            [[self imageRepresentation] isEqual:[anItem imageRepresentation]]);
}

@end
