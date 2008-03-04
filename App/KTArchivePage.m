//
//  KTArchivePage.m
//  Marvel
//
//  Created by Mike on 29/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTArchivePage.h"
#import "KTPage.h"

#import "KTHTMLParser.h"

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

- (KTElementPlugin *)plugin { return nil; }

- (KTMaster *)master { return [[self parent] master]; }

- (NSString *)dateDescription
{
	NSDate *date = [self valueForKey:@"archiveStartDate"];
	NSString *result = [date descriptionWithCalendarFormat:@"%B %Y" timeZone:nil locale:nil];
	return result;
}

- (NSArray *)sortedPages
{
	NSMutableArray *result = [NSMutableArray arrayWithArray:[[[self parent] children] allObjects]];
	
	// Filter to only pages in our date range
	NSDate *startDate = [self valueForKey:@"archiveStartDate"];
	NSDate *endDate = [self valueForKey:@"archiveEndDate"];
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"editableTimestamp BETWEEN { %@, %@ }", startDate, endDate];
	[result filterUsingPredicate:predicate];
	
	// Sort by date, newest first
	[result sortUsingDescriptors:[NSSortDescriptor reverseChronologicalSortDescriptors]];
	
	return result;
}

#pragma mark -
#pragma mark HTML

/*	Use a different template to most pages
 */
+ (NSString *)pageMainContentTemplate
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

- (NSString *)designDirectoryPath
{
	return [[self parent] designDirectoryPath];
}


@end
