//
//  KTPage+Accessors.m
//  KTComponents
//
//  Created by Dan Wood on 8/9/05.
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//

#import "KTPage.h"

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
    // To my annoyance, calling super doesn't work because it's @dynamic
    [self willChangeValueForKey:@"isDraft"];
	[self setPrimitiveValue:flag forKey:@"isDraft"];
    [self didChangeValueForKey:@"isDraft"];
	
	
	// This may also affect the site menu
	if ([[self includeInSiteMenu] boolValue])
	{
		[[self site] invalidatePagesInSiteMenuCache];
	}
}

#pragma mark -
#pragma mark Timestamp

- (NSString *)timestamp
{
	return [self timestampDescriptionWithDate:[self timestampDate]];
}

+ (NSSet *)keyPathsForValuesAffectingTimestamp
{
    return [NSSet setWithObjects:
            @"timestampDate",
            @"master.timestampFormat",
            @"master.timestampShowTime", nil];
}

- (NSDate *)timestampDate;
{
    NSDate *result = (KTTimestampModificationDate == [[self timestampType] intValue])
    ? [self modificationDate]
    : [self creationDate];
	
	return result;
}

+ (NSSet *)keyPathsForValuesAffectingTimestampDate
{
    return [NSSet setWithObjects:@"timestampType", @"creationDate", @"modificationDate", nil];
}

@dynamic includeTimestamp;
@dynamic timestampType;

- (NSString *)timestampTypeLabel
{
	NSString *result = (KTTimestampModificationDate == [[self timestampType] intValue])
		? NSLocalizedString(@"(Modification Date)",@"Label to indicate that date shown is modification date")
		: NSLocalizedString(@"(Creation Date)",@"Label to indicate that date shown is creation date");
	return result;
}

- (NSString *)timestampDescription;    // nil if page does't have/want timestamp
{
    NSString *result = nil;
    
    if ([[self includeTimestamp] boolValue])
    {
        result = [self timestamp];
    }
    
    return result;
}

#pragma mark -
#pragma mark Keywords

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
	
	/*id delegate = [self delegate];
	if (delegate && [delegate respondsToSelector:_cmd])
	{
		result = [delegate shouldMaskCustomSiteOutlinePageIcon:page];
	}*/
	
	return result;
}

- (KTCodeInjection *)codeInjection
{
    return [self wrappedValueForKey:@"codeInjection"];
}

#pragma mark Search Engines

@dynamic metaDescription;
@dynamic windowTitle;

@end
