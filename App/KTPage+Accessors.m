//
//  KTPage+Accessors.m
//  KTComponents
//
//  Created by Dan Wood on 8/9/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "KTPage.h"
#import "KTArchivePage.h"

#import "KTMaster+Internal.h"
#import "KTMediaManager.h"
#import "KTDesign.h"
#import "KTSite.h"
#import "KTDocumentController.h"
#import "KTMediaContainer.h"

#import "NSArray+Karelia.h"
#import "NSDocumentController+KTExtensions.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSData+Karelia.h"
#import "NSString+Karelia.h"

#import "Debug.h"


@interface KTPage (ChildrenPrivate)
- (void)invalidateSortedChildrenCache;
@end


@implementation KTPage (Accessors)

#pragma mark -
#pragma mark Comments

@dynamic allowComments;

/*	By default this is set to NO. Plugins can override it either in their info.plist, or dynamically at run-time
 *	using the -setDisableComments: method.
 */
- (BOOL)disableComments { return [self wrappedBoolForKey:@"disableComments"]; }

- (void)setDisableComments:(BOOL)disableComments { [self setWrappedBool:disableComments forKey:@"disableComments"]; }

#pragma mark -
#pragma mark Title

/*	Pages may need to be resorted after changing the title. This only affects KTPage, not KTAbstractPage
 */
- (void)setTitleHTMLString:(NSString *)value
{
	NSString *oldTitleText = [[self title] text];
    
    [super setTitleHTMLString:value];
	
	
	// If the page hasn't been published yet, update the filename to match
	if ([self shouldUpdateFileNameWhenTitleChanges])
	{
		[self setValue:[self suggestedFileName] forKey:@"fileName"];
	}
	
	
	// Invalidate our parent's sortedChildren cache if it is alphabetically sorted
	KTCollectionSortType sorting = [[self parentPage] collectionSortOrder];
	if (sorting == KTCollectionSortAlpha || sorting == KTCollectionSortReverseAlpha)
	{
		[[self parentPage] invalidateSortedChildrenCache];
	}
    
    
    // Update archive page titles to match
    [[self archivePages] makeObjectsPerformSelector:@selector(updateTitle)];
}

- (BOOL)shouldUpdateFileNameWhenTitleChanges
{
    return [self wrappedBoolForKey:@"shouldUpdateFileNameWhenTitleChanges"];
}

- (void)setShouldUpdateFileNameWhenTitleChanges:(BOOL)autoUpdate
{
    [self setWrappedBool:autoUpdate forKey:@"shouldUpdateFileNameWhenTitleChanges"];
}

#pragma mark -
#pragma mark Relationships

- (KTPage *)page
{
	return self;			// the containing page of this object is the page itself
}

#pragma mark -
#pragma mark Drafts

- (void)setIsDraft:(BOOL)flag;
{
	// Mark our old archive page (if there is one) stale
	KTArchivePage *oldArchivePage = [[self parentPage] archivePageForTimestamp:[self timestampDate] createIfNotFound:!flag];
	
	
	[self setWrappedBool:flag forKey:@"isDraft"];
	
	
	// Delete the old archive page if it has nothing on it now
	if (oldArchivePage)
	{
		NSArray *pages = [oldArchivePage sortedPages];
		if (!pages || [pages count] == 0) [[self managedObjectContext] deletePage:oldArchivePage];
	}
	
	
	// This may also affect the site menu
	if ([self includeInSiteMenu])
	{
		[[self valueForKey:@"site"] invalidatePagesInSiteMenuCache];
	}
	
	// And the index
	[[self parentPage] invalidatePagesInIndexCache];
}

- (BOOL)pageOrParentDraft
{
	BOOL result = [self boolForKey:@"isDraft"];
	if (!result && [self parentPage] != nil)
	{
		result = [[self parentPage] pageOrParentDraft];
	}
	return result;
}

- (void)setPageOrParentDraft:(BOOL)inDraft	// setter for binding, actually store into isDraft
{
	[self setIsDraft:inDraft];
	if (!inDraft)
	{
		// turning off draft -- also mark the family stale since it's no longer a draft
		//[self markStale:kStaleFamily];
	}
}

// Derived accessor to determine if page should be included in the index AND it has been published or not draft
// In other words, if it's a draft, don't include -- but if it's a draft that is already published, keep it

- (BOOL)includeInIndexAndPublish
{
	BOOL result = [self includeInIndex];
	if (result)
	{
		// thinks it should be in index, so see if maybe we shouldn't publish it.  Faster to check serverPath first.
		NSString *serverPath = [self publishedPath];
		if (nil == serverPath && [self boolForKey:@"isDraft"])		// Ask if page ITSELF is a draft.  Do not inherit here.
		{
			result = NO;	// DON'T include if if hasn't been published before, and if it's draft
		}
	}
	return result;
}

// Derived accessor of whether page should be excluded from a site map because flag is set, or it's an unpublished draft.

- (BOOL)excludedFromSiteMap
{
	BOOL result = ![self boolForKey:@"includeInSiteMap"];		// exclude from site map?
	if (!result)
	{
		// Not excluded by the flag, see if we should exclude it becuase it's an unpublished draft.
		NSString *serverPath = [self publishedPath];
		
		// thinks it should be in index, so see if maybe we shouldn't publish it.  Faster to check serverPath first.
		if (nil == serverPath && [self pageOrParentDraft])
		{
			result = YES;	// DON'T include if if hasn't been published before, and if it's draft
		}
	}
	return result;
}

#pragma mark Site Menu

- (BOOL)includeInSiteMenu { return [self wrappedBoolForKey:@"includeInSiteMenu"]; }

/*	In addition to a standard setter, we must also invalidate old site menu
 */
- (void)setIncludeInSiteMenu:(BOOL)include;
{
	[self setWrappedBool:include forKey:@"includeInSiteMenu"];
	[[self valueForKey:@"site"] invalidatePagesInSiteMenuCache];
}

- (NSString *)menuTitle;
{
    NSString *result = [self customMenuTitle];
    if (![result length])
    {
        result = [[self title] text];
    }
    
    return result;
}

@dynamic customMenuTitle;

#pragma mark -
#pragma mark Timestamp

@dynamic creationDate;
@dynamic lastModificationDate;

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
#pragma mark Thumbnail

+ (NSSet *)keyPathsForValuesAffectingThumbnail
{
    return [NSSet setWithObject:@"collectionSummaryType"];
}

- (KTMediaContainer *)thumbnail
{
	KTMediaContainer *result = [self wrappedValueForKey:@"thumbnail"];
	
	if (!result)
	{
		NSString *mediaID = [self valueForKey:@"thumbnailMediaIdentifier"];
		if (mediaID)
		{
			result = [[self mediaManager] mediaContainerWithIdentifier:mediaID];
			[self setPrimitiveValue:result forKey:@"thumbnail"];
		}
		else
		{
			[self setPrimitiveValue:[NSNull null] forKey:@"thumbnail"];
		}
	}
	else if ((id)result == [NSNull null])
	{
		result = nil;
	}
	
	return result;
}

- (void)_setThumbnail:(KTMediaContainer *)thumbnail
{
	OBPRECONDITION(!thumbnail || [thumbnail isKindOfClass:[KTMediaContainer class]]);
    
    [self willChangeValueForKey:@"thumbnail"];
	[self setPrimitiveValue:thumbnail forKey:@"thumbnail"];
	[self setValue:[thumbnail identifier] forKey:@"thumbnailMediaIdentifier"];
	[self didChangeValueForKey:@"thumbnail"];
	
	
	// Propogate the thumbnail to our parent if needed
	if ([[self parentPage] pageToUseForCollectionThumbnail] == self)
	{
		[[self parentPage] _setThumbnail:thumbnail];
	}
}

- (void)setThumbnail:(KTMediaContainer *)thumbnail
{
	OBPRECONDITION(!thumbnail || [thumbnail isKindOfClass:[KTMediaContainer class]]);
    
    [self setCollectionSummaryType:KTSummarizeAutomatic];
	[self _setThumbnail:thumbnail];
}


/*	Called when a setting has been changed such that the collection's thumbnail needs updating.
 */
- (void)generateCollectionThumbnail
{
	KTCollectionSummaryType summaryType = [self collectionSummaryType];
	if (summaryType == KTSummarizeFirstItem || summaryType == KTSummarizeMostRecent)
	{
		KTPage *thumbnailPage = [self pageToUseForCollectionThumbnail];
		if (thumbnailPage)
		{
			[self _setThumbnail:[thumbnailPage thumbnail]];
		}
	}
}


/*	For collections, the thumbnail is often automatically generated from a child page.
 *	This method tells you which page to use.
 */
- (KTPage *)pageToUseForCollectionThumbnail
{
	KTPage *result;
	
	switch ([self collectionSummaryType])
	{
		case KTSummarizeFirstItem:
			result = [[self sortedChildren] firstObjectKS];
			break;
		case KTSummarizeMostRecent:
			result = [[self childrenWithSorting:KTCollectionSortLatestAtTop inIndex:NO] firstObjectKS];
			break;
		default:
			result = self;
			break;
	}
	
	return result;
}

- (NSSize)maxThumbnailSize { return NSMakeSize(64.0, 64.0); }

- (BOOL)mediaContainerShouldRemoveFile:(KTMediaContainer *)mediaContainer
{
	BOOL result = YES;
	
	if (mediaContainer == [self thumbnail])
	{
		id delegate = [self delegate];
		if (delegate && [delegate respondsToSelector:@selector(pageShouldClearThumbnail:)])
		{
			result = [delegate pageShouldClearThumbnail:self];
		}
	}
	
	return result;
}

#pragma mark -
#pragma mark Keywords

- (NSArray *)keywords
{
    return [self transientValueForKey:@"keywords" persistentPropertyListKey:@"keywordsData"];
}

- (void)setKeywords:(NSArray *)keywords
{	
	[self setTransientValue:keywords forKey:@"keywords" persistentPropertyListKey:@"keywordsData"];
}

- (NSString *)keywordsList;		// comma separated for meta
{
	NSString *result = [[self keywords] componentsJoinedByString:@", "];
	return result;
}

#pragma mark -
#pragma mark Site Outline

- (KTMediaContainer *)customSiteOutlineIcon
{
	KTMediaContainer *result = [self wrappedValueForKey:@"customSiteOutlineIcon"];
	
	if (!result)
	{
		NSString *mediaID = [self valueForKey:@"customSiteOutlineIconIdentifier"];
		if (mediaID)
		{
			result = [[self mediaManager] mediaContainerWithIdentifier:mediaID];
			[self setPrimitiveValue:result forKey:@"customSiteOutlineIcon"];
		}
		else
		{
			[self setPrimitiveValue:[NSNull null] forKey:@"customSiteOutlineIcon"];
		}
	}
	else if ((id)result == [NSNull null])
	{
		result = nil;
	}
	
	return result;
}

- (void)setCustomSiteOutlineIcon:(KTMediaContainer *)icon
{
	[self willChangeValueForKey:@"customSiteOutlineIcon"];
	[self setPrimitiveValue:icon forKey:@"customSiteOutlineIcon"];
	[self setValue:[icon identifier] forKey:@"customSiteOutlineIconIdentifier"];
	[self didChangeValueForKey:@"customSiteOutlineIcon"];
}

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
