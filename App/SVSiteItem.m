// 
//  SVSiteItem.m
//  Sandvox
//
//  Created by Mike on 13/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVSiteItem.h"

#import "KTHostProperties.h"
#import "SVHTMLContext.h"
#import "SVLink.h"
#import "SVMediaRecord.h"
#import "KTPage.h"
#import "KTSite.h"]
#import "SVWebEditingURL.h"

#import "NSManagedObjectContext+KTExtensions.h"

#import "NSString+Karelia.h"


@implementation SVSiteItem 

#pragma mark Identifier

@dynamic uniqueID;

- (NSString *)identifier { return [self uniqueID]; }

+ (KTPage *)siteItemForPreviewPath:(NSString *)path inManagedObjectContext:(NSManagedObjectContext *)context;
{
	KTPage *result = nil;
	
	// skip media objects ... starting or containing Media if it's not a request in the main frame
	if ( NSNotFound == [path rangeOfString:[[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultMediaPath"]].location )
	{
		int whereTilde = [path rangeOfString:kKTPageIDDesignator options:NSBackwardsSearch].location;	// special mark internally to look up page IDs
		if (NSNotFound != whereTilde)
		{
			NSString *idString = [path substringFromIndex:whereTilde+[kKTPageIDDesignator length]];
			result = [KTPage pageWithUniqueID:idString inManagedObjectContext:context];
		}
		
        // This logic was in the SVSite equivalent of this method. Still applies?
        /*else if ([path hasSuffix:@"/"])
		{
			result = [self rootPage];
		}*/
	}
	return result;
}


#pragma mark Title

@dynamic title;

#pragma mark Dates

- (void)awakeFromInsert
{
    [super awakeFromInsert];
	
	[self setPrimitiveValue:[NSString shortUUIDString] forKey:@"uniqueID"];
    
    // attributes
	NSDate *now = [NSDate date];
	[self setPrimitiveValue:now forKey:@"creationDate"];
	[self setPrimitiveValue:now forKey:@"modificationDate"];
}

@dynamic creationDate;
@dynamic modificationDate;

#pragma mark Navigation

/*	In addition to a standard setter, we must also invalidate old site menu
 */
@dynamic includeInSiteMenu;
- (void)setIncludeInSiteMenu:(NSNumber *)include;
{
	[self setWrappedValue:include forKey:@"includeInSiteMenu"];
	[[self site] invalidatePagesInSiteMenuCache];
}

- (BOOL)shouldIncludeInSiteMenu;    // takes into account draft status etc.
{
    BOOL result = ([[self includeInSiteMenu] boolValue] && 
                   ([self datePublished] || ![self isDraftOrHasDraftAncestor]));
    return result;
}

- (NSString *)menuTitle;
{
    NSString *result = [self customMenuTitle];
    if (![result length])
    {
        result = [self title];
    }
    
    return result;
}

@dynamic customMenuTitle;

@dynamic includeInSiteMap;
@dynamic openInNewWindow;

#pragma mark Drafts and Indexes

@dynamic isDraft;
- (void)setIsDraft:(NSNumber *)flag;
{
	[self setWrappedValue:flag forKey:@"isDraft"];
	
	
	// And the index
	[[self parentPage] invalidatePagesInIndexCache];
}

- (BOOL)isDraftOrHasDraftAncestor
{
	BOOL result = [[self isDraft] boolValue];
	if (!result && [self parentPage] != nil)
	{
		result = [[self parentPage] isDraftOrHasDraftAncestor];
	}
	return result;
}

- (void)setPageOrParentDraft:(BOOL)inDraft	// setter for binding, actually store into isDraft
{
	[self setIsDraft:[NSNumber numberWithBool:inDraft]];
	if (!inDraft)
	{
		// turning off draft -- also mark the family stale since it's no longer a draft
		//[self markStale:kStaleFamily];
	}
}

// Derived accessor of whether page should be excluded from a site map because flag is set, or it's an unpublished draft.

- (BOOL)excludedFromSiteMap
{
	BOOL result = ![[self valueForKey:@"includeInSiteMap"] boolValue];		// exclude from site map?
	if (!result)
	{
		// Not excluded by the flag, see if we should exclude it becuase it's an unpublished draft.		
		// thinks it should be in index, so see if maybe we shouldn't publish it.  Faster to check serverPath first.
		if (![self datePublished] && [self isDraftOrHasDraftAncestor])
		{
			result = YES;	// DON'T include if if hasn't been published before, and if it's draft
		}
	}
	return result;
}

@dynamic includeInIndex;
- (void)setIncludeInIndex:(NSNumber *)flag
{
	[self setWrappedValue:flag forKey:@"includeInIndex"];
	
	
	// We must update the parent's list of pages
	[[self parentPage] invalidatePagesInIndexCache];
}

@dynamic isPublishableInDemo;

#pragma mark URL

// For display in the placeholder webview
- (NSURL *)URL
{
    NSString *filename = [[self fileName] legalizedWebPublishingFilename];
    
    return [[[SVWebEditingURL alloc] initWithString:filename
                                      relativeToURL:[[self parentPage] URL]
                               webEditorPreviewPath:[self previewPath]] autorelease];
}

@dynamic fileName;

- (BOOL)canPreview { return NO; }

- (NSString *)previewPath
{
	NSString *result = [NSString stringWithFormat:@"%@%@", kKTPageIDDesignator, [self uniqueID]];
	return result;
}

#pragma mark Editing

// used to determine if it's an external link, for page details.
- (SVExternalLink *)externalLinkRepresentation { return nil; }
- (KTPage *)pageRepresentation { return nil; }
- (SVMediaRecord *)mediaRepresentation; { return nil; }



- (NSURL *)_baseExampleURL;	// support. Subclasses override to be more specific if need be
{
	// Root is a sepcial case where we just supply the site URL
	NSURL *result = [[[self site] hostProperties] siteURL];
	if (!result)
	{
		result = [NSURL URLWithString:@"http://www.EXAMPLE.com/"];
	}
	// What if this contains an index.html at the end?
	return result;
}

- (NSString *)baseExampleURLString	// for page details. Subclasses override to be more specific if need be
{
	NSURL *resultURL = [self _baseExampleURL];
    NSString *result = [resultURL absoluteString];
	return result;
}


#pragma mark Publishing

@dynamic datePublished;
- (void)setDatePublished:(NSDate *)date
{
	[self setWrappedValue:date forKey:@"datePublished"];
	
	// Our status in the index could depend on this key
	[[self parentPage] invalidatePagesInIndexCache];
}

/*	Sends out a KVO notification that the page's URL has changed. Upon the next request for the URL it will be
 *	regenerated and cached.
 *	KTAbstractPage does not support children, so it is up to KTPage to implement the recursive portion.
 *
 *	If the URL is invalid, it can be assumed that the site structure must have changed, so we also post a notification.
 */
- (void)recursivelyInvalidateURL:(BOOL)recursive
{
    [self setDatePublished:nil]; // #83550
}

#pragma mark Site

@dynamic site;

- (void)setSite:(KTSite *)site recursively:(BOOL)recursive;
{
    // KTPage adds to this behaviour by recursively calling its descendants too, if requested
    [self setSite:site];
}

@dynamic master;

#pragma mark Tree

- (NSSet *)childItems { return nil; }
- (NSArray *)sortedChildren; { return nil; }

@dynamic parentPage;
- (BOOL)validateParentPage:(KTPage **)page error:(NSError **)outError;
{
    BOOL result = (*page != nil);
    if (!result && outError)
    {
        NSDictionary *info = [NSDictionary dictionaryWithObject:@"parentPage is a required property" forKey:NSLocalizedDescriptionKey];
        
        *outError = [NSError errorWithDomain:NSCocoaErrorDomain
                                        code:NSValidationMissingMandatoryPropertyError
                                    userInfo:info];
    }
    
    return result;
}

- (KTPage *)rootPage;   // searches up the tree till it finds a page with no parent
{
    KTPage *result = [[self parentPage] rootPage];
    return result;
}

- (BOOL)isRoot
{
	BOOL result = ((id)self == [[self site] rootPage]);
	return result;
}

- (BOOL)isDescendantOfCollection:(KTPage *)aPotentialAncestor;
{
	if (aPotentialAncestor == self) return YES;
    
    KTPage *parent = [self parentPage];
	if (nil == parent)		// we are at the root node, so it can't be descended from the given node
	{
		return NO;
	}
	if (aPotentialAncestor == parent)
	{
		return YES;
	}
	return [parent isDescendantOfCollection:aPotentialAncestor];
}

- (BOOL)isDescendantOfItem:(SVSiteItem *)aPotentialAncestor;
{
    BOOL result = NO;
    
    if ([aPotentialAncestor isCollection])
    {
        result = [self isDescendantOfCollection:(KTPage *)aPotentialAncestor];
    }
    
    return result;
}

- (short)childIndex { return [self wrappedIntegerForKey:@"childIndex"]; }

- (void)setChildIndex:(short)index { [self setWrappedInteger:index forKey:@"childIndex"]; }

#pragma mark Contents

// Subclasses will do something useful
- (void)publish:(id <SVPublisher>)publishingEngine recursively:(BOOL)recursive; { }

- (void)writeContent:(SVHTMLContext *)context recursively:(BOOL)recursive;
{
	if ([self title])
	{
		[context writeText:[self title]];
		[context startNewline];
	}
}

#pragma mark Thumbnail

- (id <SVMedia>)thumbnail;
{
    id <SVMedia> result = nil;
    
    if ([[self thumbnailType] integerValue] == 1)
    {
        result = [self customThumbnail];
    }
    
    return result;
}

@dynamic thumbnailType;
@dynamic customThumbnail;

#pragma mark UI

- (BOOL)isCollection { return NO; }
- (KTCodeInjection *)codeInjection; { return nil; }

#pragma mark Inspection

- (id)valueForUndefinedKey:(NSString *)key
{
    return NSNotApplicableMarker;
}

#pragma mark SVPage

- (NSArray *)childPages; { return [self sortedChildren]; }

- (id <NSFastEnumeration>)automaticRearrangementKeyPaths;
{
    static NSSet *result;
    if (!result)
    {
        result = [[NSSet alloc] initWithObjects:
                  @"childItems",
                  @"childIndex",
                  @"creationDate",
                  @"modificationDate",
                  @"title",
                  @"includeInSiteMap", nil];
    }
    
    return result;
}

- (NSArray *)archivePages; { return nil; }

- (SVLink *)link;
{
    return [SVLink linkWithSiteItem:self
                    openInNewWindow:[[self openInNewWindow] boolValue]];
}

- (NSURL *)feedURL { return nil; }

- (BOOL)shouldIncludeInIndexes;
{
    BOOL result = ([[self includeInIndex] boolValue] && 
                   ([self datePublished] || ![self isDraftOrHasDraftAncestor]));
    return result;
}

- (BOOL)shouldIncludeInSiteMaps;
{
    BOOL result = ([[self includeInSiteMap] boolValue] && 
                   ([self datePublished] || ![self isDraftOrHasDraftAncestor]));
    return result;
}

- (NSString *)language { return nil; }

#pragma mark Core Data

+ (NSString *)entityName { return @"AbstractPage"; }

/*	Picks out all the pages correspoding to self's entity
 */
+ (NSArray *)allPagesInManagedObjectContext:(NSManagedObjectContext *)MOC
{
	NSArray *result = [MOC fetchAllObjectsForEntityForName:[self entityName] error:NULL];
	return result;
}

/*	As above, but uses a predicate to narrow down to a particular ID
 */
+ (id)pageWithUniqueID:(NSString *)ID inManagedObjectContext:(NSManagedObjectContext *)MOC
{
	id result = [MOC objectWithUniqueID:ID entityName:[self entityName]];
	return result;
}

@end
