//
//  SVArchivePage.m
//  Sandvox
//
//  Created by Mike on 20/08/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVArchivePage.h"


@implementation SVArchivePage

- (id)initWithPages:(NSArray *)pages;
{
    OBPRECONDITION([pages count]);
    
    [self init];
    
    _childPages = [pages copy];
    _collection = [[[pages lastObject] parentPage] retain];
    
    return self;
}

- (void)dealloc;
{
    [_childPages release];
    [_collection release];
    
    [super dealloc];
}

@synthesize collection = _collection;

- (NSString *)identifier; { return nil; }

- (NSString *)title; { return [[[self collection] title] stringByAppendingString:@" archive"]; }

- (NSString *)language; { return [[self collection] language]; }

- (BOOL)isCollection; { return NO; }
- (NSArray *)childPages; { return _childPages; }
- (id <SVPage>)rootPage; { return [[self collection] rootPage]; }
- (id <NSFastEnumeration>)automaticRearrangementKeyPaths; { return nil; }

- (NSArray *)archivePages; { return nil; }

- (SVLink *)link; { return nil; }
- (NSURL *)feedURL { return nil; }

- (BOOL)shouldIncludeInIndexes; { return NO; }
- (BOOL)shouldIncludeInSiteMaps; { return NO; }

@end
