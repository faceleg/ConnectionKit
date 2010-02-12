//
//  SVTextBoxRange.m
//  Sandvox
//
//  Created by Mike on 12/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVTextBoxRange.h"


@implementation SVTextBoxRange

- (id)initWithStartObject:(id)startObject index:(NSUInteger)startIndex
                endObject:(id)endObject index:(NSUInteger)endIndex;
{
    [self init];
    
    _startObject = [startObject retain];
    _startIndex = startIndex;
    _endObject = [endObject retain];
    _endIndex = endIndex;
    
    return self;
}

- (void)dealloc
{
    [_startObject release];
    [_endObject release];
    
    [super dealloc];
}

@synthesize startObject = _startObject;
@synthesize startIndex = _startIndex;
@synthesize endObject = _endObject;
@synthesize endIndex = _endIndex;

@end
