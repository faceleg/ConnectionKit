//
//  SVArchivePage.m
//  Sandvox
//
//  Created by Mike on 20/08/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVArchivePage.h"

#import "SVGraphicFactory.h"
#import "SVHTMLTemplateParser.h"
#import "SVIndexPlugIn.h"
#import "KTPage+Paths.h"
#import "SVLink.h"

#import "NSObject+Karelia.h"


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

// Returns YES if truncated.

- (BOOL)writeSummary:(id <SVPlugInContext>)context includeLargeMedia:(BOOL)includeLargeMedia truncation:(NSUInteger)maxCount truncationType:(SVIndexTruncationType)truncationType; { return NO; }

- (NSString *)language; { return [[self collection] language]; }

- (BOOL)isCollection; { return NO; }
- (NSArray *)childPages; { return _childPages; }
- (id <SVPage>)rootPage; { return [[self collection] rootPage]; }
- (id <NSFastEnumeration>)automaticRearrangementKeyPaths; { return nil; }

- (NSArray *)archivePages; { return nil; }

- (NSString *)timestampDescription; { return nil; }

#pragma mark Being for the benefit of index pages controller

- (NSSet *)childItems; { return [NSSet setWithArray:[self childPages]]; }

- (NSArray *)childItemsSortDescriptors;
{
    // Always sort chronologically
    return [KTPage dateCreatedSortDescriptorsAscending:NO];
}

#pragma mark Location

- (NSURL *)URL;
{
    NSURL *result = [NSURL URLWithString:[@"archives/" stringByAppendingString:[self filename]]
                           relativeToURL:[[self collection] URL]];
    return result;
}

- (SVLink *)link;
{
    return [SVLink linkWithURLString:[[self URL] absoluteString]
                     openInNewWindow:NO];
}

- (NSURL *)feedURL { return nil; }

- (NSString *)uploadPath;
{
    NSString *directory = [[[self collection] uploadPath] stringByDeletingLastPathComponent];
    
    NSString *result = [directory stringByAppendingPathComponent:
                        [@"archives/" stringByAppendingString:[self filename]]];
    return result;
}

- (NSString *)filename;
{
    // Get the month formatted like "01_2008"
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setFormatterBehavior:NSDateFormatterBehavior10_4];
    [formatter setDateFormat:@"MM'-'yyyy'.html'"];
    
    NSDate *date = [[[self childPages] lastObject] creationDate];
	NSString *result = [formatter stringFromDate:date];
    [formatter release];
    
    return result;
}

#pragma mark Other

- (BOOL)shouldIncludeInIndexes; { return NO; }
- (BOOL)shouldIncludeInSiteMaps; { return NO; }

- (BOOL)writeThumbnail:(id <SVPlugInContext>)context
              maxWidth:(NSUInteger)width
             maxHeight:(NSUInteger)height
        imageClassName:(NSString *)className
                dryRun:(BOOL)dryRun;
{
    return NO;
}

#pragma mark Article

- (void)writeHTML;
{
    SVHTMLContext *context = [[SVHTMLTemplateParser currentTemplateParser] HTMLContext];
    
    
    SVGraphicFactory *factory = [SVGraphicFactory factoryWithIdentifier:@"sandvox.GeneralIndex"];
    SVIndexPlugIn *plugIn = [[[factory plugInClass] alloc] init];
    
    [plugIn setIndexedCollection:self];
    [plugIn setBool:YES forKey:@"hyperlinkTitles"];
    [plugIn setBool:YES forKey:@"showEntries"];
    [plugIn setBool:YES forKey:@"showTitles"];
    [plugIn setBool:YES forKey:@"showTimestamps"];
    [plugIn setInteger:3 forKey:@"indexLayoutType"]; // kLayoutTitlesAndArticles
    
    
    [plugIn writeHTML:context];
    
    [plugIn release];
}

@end
