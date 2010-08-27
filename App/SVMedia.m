//
//  SVMedia.m
//  Sandvox
//
//  Created by Mike on 27/08/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMedia.h"


@implementation SVMedia

- (id)initWithURL:(NSURL *)fileURL;
{
    [self init];
    
    _fileURL = [fileURL copy];
    
    return self;
}

- (void)dealloc;
{
    [_fileURL release];
    [_data release];
    
    [super dealloc];
}

@synthesize fileURL = _fileURL;

- (NSData *)data;
{
    NSData *result = _data;
    if (!result && [self fileURL])
    {
        result = [NSData dataWithContentsOfURL:[self fileURL]];
    }
    
    return result;
}

@end
