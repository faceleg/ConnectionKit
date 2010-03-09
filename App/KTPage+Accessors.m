//
//  KTPage+Accessors.m
//  KTComponents
//
//  Created by Dan Wood on 8/9/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "KTPage.h"
#import "KTArchivePage.h"

#import "KTMaster.h"
#import "KTDesign.h"
#import "KTSite.h"
#import "KTDocumentController.h"

#import "NSArray+Karelia.h"
#import "NSDocumentController+KTExtensions.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSData+Karelia.h"
#import "NSString+Karelia.h"

#import "Debug.h"


@implementation KTPage (Accessors)

#pragma mark Comments

@dynamic allowComments;

#pragma mark Title

- (BOOL)shouldUpdateFileNameWhenTitleChanges
{
    return [self wrappedBoolForKey:@"shouldUpdateFileNameWhenTitleChanges"];
}

- (void)setShouldUpdateFileNameWhenTitleChanges:(BOOL)autoUpdate
{
    [self setWrappedBool:autoUpdate forKey:@"shouldUpdateFileNameWhenTitleChanges"];
}

#pragma mark Relationships

- (KTPage *)page
{
	return self;			// the containing page of this object is the page itself
}

#pragma mark Drafts

- (void)setIsDraft:(NSNumber *)flag;
{
	[super setIsDraft:flag];
	
	
	// This may also affect the site menu
	if ([self includeInSiteMenu])
	{
		[[self valueForKey:@"site"] invalidatePagesInSiteMenuCache];
	}
	
	// And the index
	[[self parentPage] invalidatePagesInIndexCache];
}

#pragma mark -
#pragma mark Timestamp

- (NSString *)timestamp
{
	NSDateFormatterStyle style = [[self master] timestampFormat];
	return [self timestampWithStyle:style];
}

+ (NSSet *)keyPathsForValuesAffectingTimestamp
{
    return [NSSet setWithObject:@"timestampDate"];
}

- (NSString *)timestampWithStyle:(NSDateFormatterStyle)aStyle;
{
	BOOL showTime = [[[self master] timestampShowTime] boolValue];
	NSDate *date = [self timestampDate];
	
	NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
	[formatter setDateStyle:aStyle]; 
	
	// Minor adjustments to timestampFormat for the time style
	if (!showTime)
	{
		aStyle = NSDateFormatterNoStyle;
	}
	else
	{
		aStyle = kCFDateFormatterShortStyle;	// downgrade to short to avoid seconds
	}
	[formatter setTimeStyle:aStyle];
	
	NSString *result = [formatter stringForObjectValue:date];
	return result;
}

- (NSDate *)timestampDate;
{
    NSDate *result = (KTTimestampModificationDate == [self timestampType])
    ? [self lastModificationDate]
    : [self creationDate];
	
	return result;
}

+ (NSSet *)keyPathsForValuesAffectingTimestampDate
{
    return [NSSet setWithObjects:@"timestampType", @"creationDate", @"lastModificationDate", nil];
}

@dynamic includeTimestamp;

- (KTTimestampType)timestampType { return [self wrappedIntegerForKey:@"timestampType"]; }

- (void)setTimestampType:(KTTimestampType)timestampType
{
	OBPRECONDITION(timestampType == KTTimestampCreationDate || timestampType == KTTimestampModificationDate);
	[self setWrappedInteger:timestampType forKey:@"timestampType"];
}

- (NSString *)timestampTypeLabel
{
	NSString *result = (KTTimestampModificationDate == [self timestampType])
		? NSLocalizedString(@"(Modification Date)",@"Label to indicate that date shown is modification date")
		: NSLocalizedString(@"(Creation Date)",@"Label to indicate that date shown is creation date");
	return result;
}

#pragma mark -
#pragma mark Keywords

@dynamic keywords;

- (NSString *)keywordsList;		// comma separated for meta
{
	NSString *result = [[self keywords] componentsJoinedByString:@", "];
	return result;
}

#pragma mark -
#pragma mark Site Outline

- (BOOL)shouldMaskCustomSiteOutlinePageIcon:(KTPage *)page
{
	BOOL result = YES;
	
	id delegate = [self delegate];
	if (delegate && [delegate respondsToSelector:_cmd])
	{
		result = [delegate shouldMaskCustomSiteOutlinePageIcon:page];
	}
	
	return result;
}

- (KTCodeInjection *)codeInjection
{
    return [self wrappedValueForKey:@"codeInjection"];
}

@end
