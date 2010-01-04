//
//  KTArchivePage.m
//  Marvel
//
//  Created by Mike on 29/02/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTArchivePage.h"
#import "KTPage.h"

#import "SVHTMLTemplateParser.h"

#import "NSBundle+KTExtensions.h"
#import "NSSortDescriptor+Karelia.h"

#import "assertions.h"


@implementation KTArchivePage

+ (void)initialize
{
	[self setKeys:[NSArray arrayWithObject:@"archiveStartDate"]
		triggerChangeNotificationsForDependentKey:@"dateDescription"];
}

#pragma mark -
#pragma mark Core Data

+ (NSString *)entityName { return @"ArchivePage"; }

#pragma mark -
#pragma mark Accessors

- (KTMaster *)master { return [[self parentPage] master]; }

- (NSString *)dateDescription
{
	// set up a formatter since descriptionWithCalendarFormat:timeZone:locale: may not match site locale
	NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
	[dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
	[dateFormatter setDateFormat:@"MMMM yyyy"]; // unicode pattern for @"%B %Y"

	// find our locale from the site itself
	NSString *language = [[self master] valueForKey:@"language"];
	NSLocale *locale = [[[NSLocale alloc] initWithLocaleIdentifier:language] autorelease];
	[dateFormatter setLocale:locale];
	
	NSDate *date = [self valueForKey:@"archiveStartDate"];
	NSString *result = [dateFormatter stringFromDate:date];
	return result;
}

- (NSArray *)sortedPages
{
	NSMutableArray *result = [NSMutableArray arrayWithArray:[[[self parentPage] childPages] allObjects]];
	
	// Filter to only pages in our date range
	NSDate *startDate = [self valueForKey:@"archiveStartDate"];
	NSDate *endDate = [self valueForKey:@"archiveEndDate"];
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:
							  @"editableTimestamp BETWEEN { %@, %@ } AND includeInIndexAndPublish == 1",
							  startDate,
							  endDate];
	
	[result filterUsingPredicate:predicate];
	
	// Sort by date, newest first
	[result sortUsingDescriptors:[NSSortDescriptor reverseChronologicalSortDescriptors]];
	
	return result;
}


#pragma mark -
#pragma mark Title

/*  When updating the page title, also update filename to match
 */
- (void)setTitleHTMLString:(NSString *)value
{
    [super setTitleHTMLString:value];
    
    
    // Get the month formatted like "01_2008"
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setFormatterBehavior:NSDateFormatterBehavior10_4];
    [formatter setDateFormat:@"'archive_'MM'_'yyyy"];
    
    NSDate *date = [self valueForKey:@"archiveStartDate"];
	NSString *filename = [formatter stringFromDate:date];
    [self setFileName:filename];
    
    [formatter release];
}

/*  Generates a fresh -titleHTML value and stores it
 */
- (void)updateTitle
{
    // Give the archive a decent title
    NSString *dateDescription = [self dateDescription];
	
    NSString *archiveTitle = [NSString stringWithFormat:@"%@ %@",
                              NSLocalizedString(@"Archive", "Part of an archive's page title"),
                              dateDescription];
    
    NSString *collectionTitle = [[[self parentPage] title] text];
    if (collectionTitle && ![collectionTitle isEqualToString:@""])
    {
        archiveTitle = [NSString stringWithFormat:@"%@ %@", collectionTitle, archiveTitle];
    }
    
    [self setTitleWithString:archiveTitle];
}


/*  Overridden to append date info onto the end
 */

- (NSString *)windowTitle
{
    NSString *result = [[[self parentPage] windowTitle] stringByAppendingFormat:@" - %@", [self dateDescription]];
    return result;
}

- (NSString *)comboTitleText
{
    NSString *result = [[[self parentPage] comboTitleText] stringByAppendingFormat:@" - %@", [self dateDescription]];
    return result;
}

- (NSString *)metaDescription
{
    NSString *result = [[[self parentPage] metaDescription] stringByAppendingFormat:@" - %@", [self dateDescription]];
    return result;
}

#pragma mark -
#pragma mark HTML

/*	Use a different template to most pages
 */
- (NSString *)pageMainContentTemplate
{
	static NSString *sPageTemplateString = nil;
	
	if (!sPageTemplateString)
	{
		NSString *path = [[NSBundle bundleForClass:[self class]] overridingPathForResource:@"KTArchivePageTemplate" ofType:@"html"];
		NSData *data = [NSData dataWithContentsOfFile:path];
		sPageTemplateString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	}
	
	return sPageTemplateString;
}

- (BOOL)isXHTML { return [[self parentPage] isXHTML]; }

@end
