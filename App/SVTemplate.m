//
//  SVTemplate.m
//  Sandvox
//
//  Created by Mike on 26/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVTemplate.h"


@implementation SVTemplate

+ (SVTemplate *)templateNamed:(NSString *)name;
{
    NSString *path = [[NSBundle mainBundle] pathForResource:[name stringByDeletingPathExtension]
                                                     ofType:[name pathExtension]];
    
    SVTemplate *result = nil;
    if (path)
    {
        result = [[self alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path
                                                                isDirectory:NO]];
        [result autorelease];
    }
    
    return result;
}

- (id)initWithContentsOfURL:(NSURL *)url;
{
    OBPRECONDITION(url);
    
    [self init];
    
    _templateString = [[NSString alloc] initWithContentsOfURL:url];
    if (!_templateString)
    {
        [self release]; self = nil;
    }
    
    return self;
}

@synthesize templateString = _templateString;

@end
