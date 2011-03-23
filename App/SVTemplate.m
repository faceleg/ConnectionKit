//
//  SVTemplate.m
//  Sandvox
//
//  Created by Mike on 26/12/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVTemplate.h"


@implementation SVTemplate

#pragma mark Init & Dealloc
static NSMapTable *sNamedImages;
+ (void)initialize
{
    if (!sNamedImages) sNamedImages = [[NSMapTable mapTableWithStrongToWeakObjects] retain];
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

- (void)dealloc;
{
    // Make sure we're removed from the cache to keep the zombie apocalypse at bay
    [self setName:nil];
    OBASSERT(!_name);
    
    [_templateString release];
    
    [super dealloc];
}

#pragma mark Cache

+ (SVTemplate *)templateNamed:(NSString *)name;
{
    SVTemplate *result = [sNamedImages objectForKey:name];
    if (!result)
    {
        NSString *path = [[NSBundle mainBundle] pathForResource:[name stringByDeletingPathExtension]
                                                         ofType:[name pathExtension]];
        
        if (path)
        {
			NSURL *url = [NSURL fileURLWithPath:path isDirectory:NO];
            SVTemplate *newTemplate = [[self alloc] initWithContentsOfURL:url];
            [newTemplate setName:name];
            [newTemplate autorelease];
			
			result = newTemplate;
        }
    }
   
    return result;
}

@synthesize name = _name;

- (BOOL)setName:(NSString *)name;
{
    BOOL result = YES;
    
    
    // Store under the new name if possible, or remove from cache
    if (name)
    {
        result = ([sNamedImages objectForKey:name] == nil);
        if (result)
        {
            [self setName:nil]; // remove from cache under old name
            
            name = [name copy]; // store (under) new
            [sNamedImages setObject:self forKey:name];
            [_name release]; _name = name;
        }
    }
    else if ([self name])
    {
        [sNamedImages removeObjectForKey:[self name]];
        [_name release]; _name = nil;
    }
    
    return result;
}

#pragma mark Properties
@synthesize templateString = _templateString;

@end
