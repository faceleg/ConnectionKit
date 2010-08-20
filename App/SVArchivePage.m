//
//  SVArchivePage.m
//  Sandvox
//
//  Created by Mike on 20/08/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVArchivePage.h"


@implementation SVArchivePage

- (id)initWithCollection:(KTPage *)collection;
{
    [self init];
    _collection = [collection retain];
    return self;
}

@synthesize collection = _collection;

- (NSString *)identifier; { return nil; }

- (NSString *)title; { return [[[self collection] title] stringByAppendingString:@" archive"]; }

- (NSString *)language; { return [[self collection] language]; }

- (BOOL)isCollection; { return NO; }
- (NSArray *)childPages; { return nil; }    // would be good to return pages in archive
- (id <SVPage>)rootPage; { return [[self collection] rootPage]; }
- (id <NSFastEnumeration>)automaticRearrangementKeyPaths; { return nil; }

- (NSArray *)archivePages; { return nil; }

- (SVLink *)link; { return nil; }
- (NSURL *)feedURL { return nil; }

- (BOOL)shouldIncludeInIndexes; { return NO; }
- (BOOL)shouldIncludeInSiteMaps; { return NO; }

@end
