//
//  SVMediaRepresentation.m
//  Sandvox
//
//  Created by Mike on 12/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMediaRepresentation.h"

#import "SVMediaRecord.h"


@implementation SVMediaRepresentation

- (id)initWithMediaRecord:(SVMediaRecord *)mediaRecord;
{
    [self init];
    
    _mediaRecord = [mediaRecord retain];
    
    return self;
}

- (id)initWithMediaRecord:(SVMediaRecord *)mediaRecord
                    width:(NSNumber *)width
                   height:(NSNumber *)height;
{
    self = [self initWithMediaRecord:mediaRecord];
    
    _width = [width copy];
    _height = [height copy];
    
    return self;
}

- (void)dealloc
{
    [_mediaRecord release];
    [_width release];
    [_height release];
    
    [super dealloc];
}

@synthesize mediaRecord = _mediaRecord;
@synthesize width = _width;
@synthesize height = _height;

- (NSData *)data;
{
    if ([self width] || [self height])
    {
        
    }
    else
    {
        return [[self mediaRecord] fileContents];
    }
}

@end
