//
//  KTPage+Accessors.m
//  KTComponents
//
//  Created by Dan Wood on 8/9/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTPage.h"

#import "KTMaster.h"
#import "KTMediaManager.h"
#import "KTDesign.h"

#import "Debug.h"
#import "NSAttributedString+Karelia.h"
#import "NSDocumentController+KTExtensions.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSData+Karelia.h"
#import "NSString+Karelia.h"
#import "NSString-Utilities.h"


@interface KTPage (ChildrenPrivate)
- (void)invalidateSortedChildrenCache;
@end


@implementation KTPage (Accessors)

#pragma mark -
#pragma mark Simple Accessors

- (BOOL)isStale { return [self wrappedBoolForKey:@"isStale"]; }

- (void)setIsStale:(BOOL)stale
{
	BOOL valueWillChange = (stale != [self boolForKey:@"isStale"]);
	
	if (valueWillChange)
	{
		[self setWrappedBool:stale forKey:@"isStale"];
	}
}

/*	By default this is set to NO. Plugins can override it either in their info.plist, or dynamically at run-time
 *	using the -setDisableComments: method.
 */
- (BOOL)disableComments { return [self wrappedBoolForKey:@"disableComments"]; }

- (void)setDisableComments:(BOOL)disableComments { [self setWrappedBool:disableComments forKey:@"disableComments"]; }

#pragma mark -
#pragma mark Pro

- (NSString *)googleAnalytics
{
	// should return full Google <script> so it can just plug into template
	NSString *result = [self wrappedValueForKey:@"googleAnalytics"];
	
	if (	NSNotFound == [result rangeOfString:@"<"].location
		&&	NSNotFound == [result rangeOfString:@"\""].location )
	{
		// put result, if it's just the ID, into the rest of the required text
		/// use of urchin.js is now known as the "legacy" tracking script by Google
		///result = [NSString stringWithFormat:@"<script src=\"http://www.google-analytics.com/urchin.js\" type=\"text/javascript\">\n</script>\n<script type=\"text/javascript\">\n_uacct = \"%@\";\nurchinTracker();\n</script>",result];
		/// new Google Analytics tracking script, as of 12/26/07
		result = [NSString stringWithFormat:@"<script type=\"text/javascript\">\nvar gaJsHost = ((\"https:\" == document.location.protocol) ? \"https://ssl.\" : \"http://www.\");\ndocument.write(unescape(\"%%3Cscript src='\" + gaJsHost + \"google-analytics.com/ga.js' type='text/javascript'%%3E%%3C/script%%3E\"));\n</script>\n<script type=\"text/javascript\">\nvar pageTracker = _gat._getTracker(\"%@\");\npageTracker._initData();\npageTracker._trackPageview();\n</script>", result];
	}
	return result;
}

- (void)setGoogleAnalytics:(NSString *)aString
{
	// scan here to see if we got an ID or code
	// should store the full Google <script> so getter yields complete result
	[self setWrappedValue:aString forKey:@"googleAnalytics"];
}

- (NSString *)googleSiteVerification
{
	// should be a complete <meta> tag supplied by Google
	NSString *result = [self wrappedValueForKey:@"googleSiteVerification"];

	if (	NSNotFound == [result rangeOfString:@"<"].location
			&&	NSNotFound == [result rangeOfString:@"\""].location )
	{
		// put result, if it's just the ID, into the rest of the required text
		result = [NSString stringWithFormat:@"<meta name=\"verify-v1\" content=\"%@\" />",result];
	}
	return result;
}

- (void)setGoogleSiteVerification:(NSString *)aString
{
	[self setWrappedValue:aString forKey:@"googleSiteVerification"];
}

#pragma mark -
#pragma mark Relationships

- (KTPage *)page
{
	return self;			// the containing page of this object is the page itself
}

/*!	A root page needs a direct pointer to document
*/
- (KTDocument *)document
{
	if ( nil != myDocument )		// for root
	{
		return myDocument;
	}
//	else if ( (self != [self parent]) && (nil != [[self parent] document]) )	// first clause to prevent infinite recursion
//	{
//		return [[self parent] document];
//	}
//	else
//	{
//		return (KTDocument *)[[NSDocumentController sharedDocumentController] documentForManagedObjectContext:[self managedObjectContext]];
//	}
	
	return [super document];
}

/*	Weak ref to the document.
 */
- (void)setDocument:(KTDocument *)aDocument { myDocument = aDocument; }

#pragma mark -
#pragma mark Drafts

- (BOOL)pageOrParentDraft
{
	BOOL result = [self boolForKey:@"isDraft"];
	if (!result && [self parent] != nil)
	{
		result = [[self parent] pageOrParentDraft];
	}
	return result;
}

- (void)setPageOrParentDraft:(BOOL)inDraft	// setter for binding, actually store into isDraft
{
	[self setWrappedValue:[NSNumber numberWithBool:inDraft] forKey:@"isDraft"];
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
	BOOL result = [self boolForKey:@"includeInIndex"];
	if (result)
	{
		// thinks it should be in index, so see if maybe we shouldn't publish it.  Faster to check serverPath first.
		NSString *serverPath = [self wrappedValueForKey:@"publishedPath"];
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
	BOOL result = [self boolForKey:@"addBool1"];		// exclude from site map?
	if (!result)
	{
		// Not excluded by the flag, see if we should exclude it becuase it's an unpublished draft.
		NSString *serverPath = [self wrappedValueForKey:@"publishedPath"];
		
		// thinks it should be in index, so see if maybe we shouldn't publish it.  Faster to check serverPath first.
		if (nil == serverPath && [self pageOrParentDraft])
		{
			result = YES;	// DON'T include if if hasn't been published before, and if it's draft
		}
	}
	return result;
}

#pragma mark -
#pragma mark Title

// Flatten the string and just store a fake attributed string.

- (void)setTitleHTML:(NSString *)value
{
	// set titleAttributed FIRST
	NSString *titleText = [value flattenHTML];
	NSAttributedString *attrString = [NSAttributedString systemFontStringWithString:titleText];
	
	[self setPrimitiveValue:[attrString archivableData] forKey:@"titleAttributed"];
	[self setWrappedValue:value forKey:@"titleHTML"];
	
	// If the page hasn't been published yet, update the filename to match
	if (![self valueForKey:@"publishedPath"])
	{
		[self setValue:[self suggestedFileName] forKey:@"fileName"];
	}
	
	// Invalidate our parent's sortedChildren cache if it is alphabetically sorted
	KTCollectionSortType sorting = [[self parent] collectionSortOrder];
	if (sorting == KTCollectionSortAlpha || sorting == KTCollectionSortReverseAlpha)
	{
		[[self parent] invalidateSortedChildrenCache];
	}
}

- (NSString *)titleText	// get title, but without attributes
{
	NSString *html = [self valueForKey:@"titleHTML"];
	NSString *result = [html flattenHTML];
	return result;
}

// We set attributed title, but since we're giving it plain text, it's just an attributed version of that.

- (void)setTitleText:(NSString *)value
{
	[self setTitleHTML:[value escapedEntities]];
}

// For bindings.  We can edit title if we aren't root; and if there is a delegate to override absolutePathAllowingIndexPage:,
// and it doesn't return nil.
- (BOOL)canEditTitle
{
	BOOL result = ![self isRoot];
	if (result)
	{
		id del = [self delegate];
		result = ![del respondsToSelector:@selector(absolutePathAllowingIndexPage:)];
		if (!result)	// if overridden, give it a chance to redeem itself by returning nil.  Ask delegate directly so it doesn't convert to page ID
		{
			result = (nil == [del absolutePathAllowingIndexPage:YES]);	// if this returns nil, then we CAN edit.
		}
	}
	return result;
}

#pragma mark -
#pragma mark Site Menu

- (BOOL)includeInSiteMenu { return [self wrappedBoolForKey:@"includeInSiteMenu"]; }

/*	In addition to a standard setter, we must also invoke KVO notifications on document.siteMenu
 */
- (void)setIncludeInSiteMenu:(BOOL)include;
{
	[[self document] willChangeValueForKey:@"siteMenu"];
	[self setWrappedBool:include forKey:@"includeInSiteMenu"];
	[[self document] didChangeValueForKey:@"siteMenu"];
}

/*	Used when determining if a page should be highlighted in the Site Menu.
 *	Searches up our list of parents to find the first one that appears in the menu.
 */
- (KTPage *)firstParentOrSelfInSiteMenu;
{
	KTPage *result = nil;
	
	if ([self includeInSiteMenu])
	{
		result = self;
	}
	else
	{
		result = [[self parent] firstParentOrSelfInSiteMenu];
	}
	
	return result;
}

- (NSString *)menuTitle { return [self wrappedValueForKey:@"menuTitle"]; }

- (void)setMenuTitle:(NSString *)newTitle
{
	[[self document] willChangeValueForKey:@"siteMenu"];
	[self setWrappedValue:newTitle forKey:@"menuTitle"];
	[[self document] didChangeValueForKey:@"siteMenu"];
}

/*	The HTML to use for the Site Menu. Picks from -menuTitle or -titleText appropriately
 */
- (NSString *)menuTitleOrTitle
{
	NSString *result = [self menuTitle];
    if (nil == result || [result isEqualToString:@""])
	{
		result = [self titleText];
	}
	
	result = [result escapedEntities];
	
	// Then convert spaces to be non-breaking since we don't want a fragmented menu
	if ([[[self master] design] menusUseNonBreakingSpaces])
	{
		result = [result stringByReplacing:@" " with:@"&nbsp;"];
	}
	
	return result;
}

#pragma mark -
#pragma mark Timestamp

- (NSDate *)editableTimestamp { return [self wrappedValueForKey:@"editableTimestamp"]; }

- (void)setEditableTimestamp:(NSDate *)aDate
{
	[self willChangeValueForKey:@"editableTimestamp"];
	[self setPrimitiveValue:aDate forKey:@"editableTimestamp"];
	
	// Also update the corresponding persistent attribute
	switch ([[self master] integerForKey:@"timestampType"])
	{
		case KTTimestampCreationDate:
			[self setValue:aDate forKey:@"creationDate"];
			break;
		case KTTimestampModificationDate:
			[self setValue:aDate forKey:@"modificationDate"];
			break;
	}
	
	[self didChangeValueForKey:@"editableTimestamp"];
	
	// Invalidate our parent's sortedChildren cache if it is alphabetically sorted
	KTCollectionSortType sortType = [[self parent] collectionSortOrder];
	if (sortType == KTCollectionSortLatestAtTop || sortType == KTCollectionSortLatestAtBottom)
	{
		[[self parent] invalidateSortedChildrenCache];
	}
}

/*	Internally set the editableTimestamp property from corresponding permanent attribute
 */
- (void)loadEditableTimestamp
{
	NSDate *date = nil;
	switch ([[self master] integerForKey:@"timestampType"])
	{
		case KTTimestampCreationDate:
			date = [self valueForKey:@"creationDate"];
			break;
		case KTTimestampModificationDate:
			date = [self valueForKey:@"modificationDate"];
			break;
	}
	
	[self willChangeValueForKey:@"editableTimestamp"];
	[self setPrimitiveValue:date forKey:@"editableTimestamp"];
	[self didChangeValueForKey:@"editableTimestamp"];
}

- (NSString *)timestampWithStyle:(NSDateFormatterStyle)aStyle;
{
	BOOL showTime = [[[self master] valueForKey:@"timestampShowTime"] boolValue];
	NSCalendarDate *date = (KTTimestampModificationDate == [[self master] integerForKey:@"timestampType"])
	? [self wrappedValueForKey:@"lastModificationDate"]
	: [self wrappedValueForKey:@"creationDate"];
	
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

- (NSString *)timestamp
{
	NSDateFormatterStyle style = [[[self master] valueForKey:@"timestampFormat"] intValue];
	return [self timestampWithStyle:style];
}

- (NSString *)timestampAlways
{
	return [self timestampWithStyle:kCFDateFormatterMediumStyle];		// HARD-WIRE ????
}

- (NSString *) timestampTypeLabel
{
	NSString *result = (KTTimestampModificationDate == [[self master] integerForKey:@"timestampType"])
		? NSLocalizedString(@"(Modification Date)",@"Label to indicate that date shown is modification date")
		: NSLocalizedString(@"(Creation Date)",@"Label to indicate that date shown is creation date");
	return result;
}
	
#pragma mark -
#pragma mark Thumbnail

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

- (void)setThumbnail:(KTMediaContainer *)thumbnail
{
	[self willChangeValueForKey:@"thumbnail"];
	[self setPrimitiveValue:thumbnail forKey:@"thumbnail"];
	[self setValue:[thumbnail identifier] forKey:@"thumbnailMediaIdentifier"];
	[self didChangeValueForKey:@"thumbnail"];
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

@end
