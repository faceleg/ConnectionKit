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

- (void)dealloc
{
    [_mediaRecord release];
    [super dealloc];
}

@synthesize mediaRecord = _mediaRecord;

@end
