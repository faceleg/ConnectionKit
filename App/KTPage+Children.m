//
//  KTPage+Collections.m
//  Marvel
//
//  Created by Mike on 30/01/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTPage.h"
#import "KTArchivePage.h"

#import "KTDocumentInfo.h"

#import "NSArray+Karelia.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSSortDescriptor+Karelia.h"

#import "Debug.h"


@interface KTPage (ChildrenPrivate)

- (short)childIndex;
- (void)setChildIndex:(short)index;

- (void)invalidateSortedChildrenCache;
+ (void)setCollectionIndexForPages:(NSArray *)pages;

+ (NSPredicate *)includeInIndexAndPublishPredicate;
- (NSArray *)sortDescriptorsForCollectionSortType:(KTCollectionSortType)sortType;
+ (NSSet *)sortedChildrenDependentChildrenKeys;

@end


#pragma mark -


@implementation KTPage (Children)

#pragma mark -
#pragma mark Basic Accessors

- (KTCollectionSortType)collectionSortOrder
{
	KTCollectionSortType result = [self wrappedIntegerForKey:@"collectionSortOrder"];
	
	OBPOSTCONDITION(result != KTCollectionSortUnspecified);
	return result;
}

- (void)setCollectionSortOrder:(KTCollectionSortType)sorting
{
	[self setWrappedInteger:sorting forKey:@"collectionSortOrder"];
	
	// When switching TO manual sorting ensure child indexes are up-to-date
	if (sorting == KTCollectionUnsorted)
	{
		[KTPage setCollectionIndexForPages:[self sortedChildren]];
	}
	
	// Since the sort ordering has changed the sortedChildren cache must be invalid
	[self invalidateSortedChildrenCache];
}

/*!	simple wrapper; defined for convenience of calling it.  Not optional property, so this should be OK.
*/
- (BOOL)isCollection	
{
	BOOL result = [[self wrappedValueForKey:@"isCollection"] boolValue];
	return result;		// not an optional property, so it's OK to convert to a non-object
}

#pragma mark -
#pragma mark Index

/*	-collectionIndex and -setCollectionIndex are private methods that -sortedChildren uses internally.
 *	The public API for this is the -moveToIndex: method which calls -setCollectionIndex on all affected siblings
 *	and updates the parent's -sortedChildren cache.
 *
 *	Calling this method upon a page with no parent, or within a sorted collection will raise an exception.
 */

- (void)moveToIndex:(unsigned)index
{
	KTPage *parent = [self parent];
	
	NSAssert1(parent, @"-%@ called upon page with not in a collection", NSStringFromSelector(_cmd));
	NSAssert1(([parent collectionSortOrder] == KTCollectionUnsorted),
			   @"-%@ called upon page in a sorted collection", NSStringFromSelector(_cmd));
	
	// Change our index and that of any affected siblings
	NSMutableArray *newSortedChildren = [NSMutableArray arrayWithArray:[parent sortedChildren]];
	unsigned whereSelfInParent = [newSortedChildren indexOfObjectIdenticalTo:self];
	
	// Check that we were actually found.  Mystery case 34642.  
	if (whereSelfInParent != NSNotFound && index <= [newSortedChildren count])
	{
		[newSortedChildren moveObjectAtIndex:whereSelfInParent toIndex:index];
		[KTPage setCollectionIndexForPages:newSortedChildren];
		
		// Invalidate our parent's sortedChildren cache
		[parent invalidateSortedChildrenCache];
	}
	else
	{
		NSLog(@"moveToIndex: trying to move from %d to %d in an array of %d elements", whereSelfInParent, index, [newSortedChildren count]);
	}
}

- (short)childIndex { return [self wrappedIntegerForKey:@"childIndex"]; }

- (void)setChildIndex:(short)index { [self setWrappedInteger:index forKey:@"childIndex"]; }

#pragma mark -
#pragma mark Unsorted Children

- (NSSet *)children { return [self wrappedValueForKey:@"children"]; }

/*	Adds the specified page to the receiver's children relationship.
 *
 *	If the receiver is sorted manually this method behaves like -[NSArray addObject:] and the page is
 *	placed at the end of the list.
 */
- (void)addPage:(KTPage *)page
{
	OBPRECONDITION(page);
	
	// To have a child page we must be a collection
	[self setBool:YES forKey:@"isCollection"];
	
	
	// If inserting a page into a manually sorted collection, place the page at the end of it
	if ([self collectionSortOrder] == KTCollectionUnsorted)
	{
		unsigned index = [[[self sortedChildren] lastObject] childIndex] + 1;
		[page setChildIndex:index];
	}
	
	
	// Attach the page to ourself and update the page cache
	[page setValue:self forKey:@"parent"];
	[self invalidateSortedChildrenCache];
	
	
	// As it has a new parent, the page's path must have changed.
	[page recursivelyInvalidateURL:YES];
	
	
	// Create an archive to conatain the page if needed
	[self archivePageForTimestamp:[page editableTimestamp] createIfNotFound:YES];
}


/*	This method is remarkably simple since when you remove a page there is actually no need to update
 *	the childrens' -collectionIndex. They are ultimately still in the right overall order.
 */
- (void)removePage:(KTPage *)aPage
{
	// Remove the page and update the page cache
	[[self mutableSetValueForKey:@"children"] removeObject:aPage];
	[self invalidateSortedChildrenCache];
	
	// Delete the corresponding archive page if unused now
	KTArchivePage *archive = [self archivePageForTimestamp:[aPage editableTimestamp] createIfNotFound:NO];
	if (archive)
	{
		NSArray *archivePages = [archive sortedPages];
		if ([archivePages count] == 0)
		{
			[[self managedObjectContext] deleteObject:archive];
		}
	}
}


/*	Batch equivalent of the above method. It's significantly faster because we guarantee that the
 *	-sortedChildren cache will only be invalidated the once.
 */
- (void)removePages:(NSSet *)pages
{
	[[self mutableSetValueForKey:@"children"] minusSet:pages];
	[self invalidateSortedChildrenCache];
	
	// Delete / mark stale the corresponding archive pages if unused now
	NSEnumerator *pagesEnumerator = [pages objectEnumerator];
	KTPage *aPage;
	while (aPage = [pagesEnumerator nextObject])
	{
		KTArchivePage *archive = [self archivePageForTimestamp:[aPage editableTimestamp] createIfNotFound:NO];
		if (archive)
		{
			NSArray *archivePages = [archive sortedPages];
			if ([archivePages count] == 0)
			{
				[[self managedObjectContext] deleteObject:archive];
			}
		}
	}
}

#pragma mark -
#pragma mark Sorted Children

/*	Returns our child pages in the correct ordering.
 *	The result is cached since calculating it is expensive for large collections.
 *	-sortedChildren is KVO-compliant.
 */
- (NSArray *)sortedChildren
{
	NSArray *result = [self wrappedValueForKey:@"sortedChildren"];
	if (!result)
	{
		result = [self childrenWithSorting:KTCollectionSortUnspecified inIndex:NO];
		[self setPrimitiveValue:result forKey:@"sortedChildren"];
	}
	
	return result;
}


/*	Runs through the pages in the array and makes sure their -collectionIndex property matches
 *	the position in the array.
 *	This is a support method ONLY. It does NOT update any -sortedChildren caches.
 */
+ (void)setCollectionIndexForPages:(NSArray *)pages
{
	unsigned i;
	for (i=0; i<[pages count]; i++)
	{
		KTPage *aPage = [pages objectAtIndex:i];
		[aPage setChildIndex:i];
	}
}

+ (NSSet *)sortedChildrenDependentChildrenKeys
{
	static NSSet *result;
	
	if (!result)
	{
		[NSSet setWithObjects:@"previousPage", @"nextPage", nil];
	}
	
	return result;
}

- (void)invalidateSortedChildrenCache
{
	// Clear the cache
	[self willChangeValueForKey:@"sortedChildren"];
	[[self children] makeObjectsPerformSelector:@selector(willChangeValuesForKeys:)
									 withObject:[KTPage sortedChildrenDependentChildrenKeys]];
	
	[self setPrimitiveValue:nil forKey:@"sortedChildren"];
	
	[[self children] makeObjectsPerformSelector:@selector(didChangeValuesForKeys:)
									 withObject:[KTPage sortedChildrenDependentChildrenKeys]];
	[self didChangeValueForKey:@"sortedChildren"];
	
	
	// Logically this change must have affected the index
	[self invalidatePagesInIndexCache];
	
	// Also, the site menu may well have been affected
	[[self valueForKey:@"documentInfo"] invalidatePagesInSiteMenuCache];
	
	// For some collections, this change will have affected their thumbnail
	[self generateCollectionThumbnail];
}


#pragma mark arbitrary sorting

/*	Public support method that will return the receiver's children with the specified sorting.
 *	If ignoreDrafts==YES then UNPUBLISHED drafts are filtered out.
 *	Not cached like -sortedChildren.
*/
- (NSArray *)childrenWithSorting:(KTCollectionSortType)sortType inIndex:(BOOL)ignoreDrafts
{
	NSArray *result = [[self children] allObjects];
	
	
	// Filter out drafts if requested
	if (ignoreDrafts)
	{
		result = [result filteredArrayUsingPredicate:[[self class] includeInIndexAndPublishPredicate]];
	}
	
	
	// Sometimes there's no point in sorting
	if ([result count] > 1)
	{		
		// Do the sort
		NSArray *sortDescriptors = [self sortDescriptorsForCollectionSortType:sortType];
		result = [result sortedArrayUsingDescriptors:sortDescriptors];
	}	
	
	
	return result;
}
		
+ (NSPredicate *)includeInIndexAndPublishPredicate
{
	static NSPredicate *result;
	if (!result)
	{
		result = [[NSPredicate predicateWithFormat:@"includeInIndexAndPublish == 1"] retain];
	}
	
	return result;
}

/*	Translates between KTCollectionSortType & the right sort descriptor objects
 */
- (NSArray *)sortDescriptorsForCollectionSortType:(KTCollectionSortType)sortType
{
	NSArray *result;
	switch (sortType)
	{
		case KTCollectionSortUnspecified:	// Use whatever is currently selected for this collection
			result = [self sortDescriptorsForCollectionSortType:[self collectionSortOrder]];
			break;
		case KTCollectionSortAlpha:
			result = [NSSortDescriptor alphabeticalTitleTextSortDescriptors];
			break;
		case KTCollectionSortReverseAlpha:
			result = [NSSortDescriptor reverseAlphabeticalTitleTextSortDescriptors];
			break;
		case KTCollectionSortLatestAtBottom:
			result = [NSSortDescriptor chronologicalSortDescriptors];
			break;
		case KTCollectionSortLatestAtTop:
			result = [NSSortDescriptor reverseChronologicalSortDescriptors];
			break;
		default:
			result = [NSSortDescriptor unsortedPagesSortDescriptors];	// use the "childIndex" values
			break;
	}
	
	return result;
}

#pragma mark -
#pragma mark Page Hierarchy Queries

- (KTPage *)parentOrRoot
{
	KTPage *result = [self parent];
	if (nil == result)
	{
		result = self;
	}
	return result;
}

/*	Every page bar root should have a parent.
 */
- (BOOL)validateParent:(KTPage **)aPage error:(NSError **)outError
{
	BOOL result = YES;
	if (![[[self entity] name] isEqualToString:@"Root"])
	{
		result = (aPage != nil);
		if (!result)
		{
			// Something went wrong. We need to generate an error object
			NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
				self, NSValidationObjectErrorKey,
				@"parent", NSValidationKeyErrorKey,
				NSLocalizedString(@"Page without a parent","Validation error"), NSLocalizedDescriptionKey, nil];
			
			if (outError)
			{
				*outError = [NSError errorWithDomain:@"KTPage" code:0 userInfo:userInfo];
			}
		}
	}
	
	return result;
}

- (BOOL)hasChildren
{
	NSSet *children = [self valueForKey:@"children"];
	BOOL result = ([children count] > 0);
	return result;
}

- (BOOL)containsDescendant:(KTPage *)aPotentialDescendant
{
	if ( ![self hasChildren] )
	{
		return NO;
	}
	else
	{
		NSEnumerator *e = [[self children] objectEnumerator];
		KTPage *child;
		while ( child = [e nextObject] )
		{
			if ( [child isEqual:aPotentialDescendant] )
			{
				return YES;
			}
			else if ( [child hasChildren] )
			{
				if ( [child containsDescendant:aPotentialDescendant] )
				{
					return YES;
				}
			}
		}
	}
	
	return NO;
}

/*	Returns the page's index path relative to root parent. i.e. the DocumentInfo object.
 *	This means every index starts with 0 to signify root.
 */
- (NSIndexPath *)indexPath;
{
	NSIndexPath *result = nil;
	
	KTPage *parent = [self parent];
	if (parent)
	{
		unsigned index = [[parent sortedChildren] indexOfObjectIdenticalTo:self];
		
        // BUGSID: 30402. NSNotFound really shouldn't happen, but if so we need to track it down.
        if (index == NSNotFound)
        {
            if ([[parent children] containsObject:self])
            {
                OBASSERT_NOT_REACHED("parent's -sortedChildren must be out of date");
            }
            else
            {
                NSLog(@"Parent to child relationship is broken.\nChild:\n%@\nDeleted:%d\n",
                      self,                     // Used to be an assertion. Now, we return nil and expect the
                      [self isDeleted]);       // original caller to tidy up.
            }
        }
		else
        {
            NSIndexPath *parentPath = [parent indexPath];
            result = [parentPath indexPathByAddingIndex:index];
        }
	}
	else if ([self isRoot])
	{
		result = [NSIndexPath indexPathWithIndex:0];
	}
	
    
	return result;
}

#pragma mark -
#pragma mark Should probably be deprecated

/*! returns a suggested ordering value for inserting aProposedChild
	based on aSortType -- used for intra-app dragging */
- (int)proposedOrderingForProposedChild:(id)aProposedChild
							   sortType:(KTCollectionSortType)aSortType
{
    NSSet *values = [self children];
	
	if (0 == [values count])
	{
		// if there are no other children, stick aProposedChild at the top
		return 0;
	}
	
	int result = 0;
	// copy the array
	NSMutableArray *childArray = [[values allObjects] mutableCopy];
	// stick aProposedChild in the array
	[childArray addObject:aProposedChild];
	// sort it
	NSArray *descriptors = nil;
	switch ( aSortType )
	{
		case KTCollectionSortAlpha:
			descriptors = [NSSortDescriptor alphabeticalTitleTextSortDescriptors];
			break;
		case KTCollectionSortReverseAlpha:
			descriptors = [NSSortDescriptor reverseAlphabeticalTitleTextSortDescriptors];
			break;
		case KTCollectionSortLatestAtBottom:
			descriptors = [NSSortDescriptor chronologicalSortDescriptors];
			break;
		case KTCollectionSortLatestAtTop:
			descriptors = [NSSortDescriptor reverseChronologicalSortDescriptors];
			break;
		default:
			descriptors = [NSSortDescriptor orderingSortDescriptors];	// use the "ordering" values
			break;
	}
	[childArray sortUsingDescriptors:descriptors];
	// return the index of aProposedChild in the sorted array
	result = [childArray indexOfObject:aProposedChild];
	[childArray release];
	
	//LOG((@"return proposed child drop index: %i", result));
	return result;
}

- (int)proposedOrderingForProposedChildWithTitle:(NSString *)aTitle
{
	// we'll add _zzz to the end of the title so that it's hopefully different
	// just in case the list already has seven things called "Untitled Page"
	NSString *sortableTitle = [aTitle stringByAppendingString:@"_zzz"];
	
	NSMutableArray *titlesArray = [NSMutableArray array];
	[titlesArray addObject:sortableTitle];
	
    NSSet *children = [self children];
	
	NSEnumerator *e = [children objectEnumerator];
	KTPage *child;
	while ( child = [e nextObject] )
	{
		[titlesArray addObject:[child titleHTML]];
	}
	[titlesArray sortUsingSelector:@selector(caseInsensitiveCompare:)];
	int result = [titlesArray indexOfObject:sortableTitle];
	
	//LOG((@"return proposed child drop index: %i sortedArray: %@", result, sortedArray));
	return result;
}

@end
