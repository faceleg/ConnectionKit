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

- (NSString *)title;
{
	// set up a formatter since descriptionWithCalendarFormat:timeZone:locale: may not match site locale
	NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
	[dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
	[dateFormatter setDateFormat:@"MMMM yyyy"]; // unicode pattern for @"%B %Y"
    
	// find our locale from the site itself
	NSString *language = [self language];
	NSLocale *locale = [[[NSLocale alloc] initWithLocaleIdentifier:language] autorelease];
	[dateFormatter setLocale:locale];
	
	NSDate *date = [[[self childPages] lastObject] creationDate];
	NSString *result = [dateFormatter stringFromDate:date];
	return result;
}

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
