//
//  KTPage+Collections.m
//  Marvel
//
//  Created by Mike on 30/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTPage.h"

#import "NSSortDescriptor+KTExtensions.h"


@interface KTPage (ChildrenPrivate)

- (short)childIndex;
- (void)setChildIndex:(short)index;

- (NSMutableArray *)sortedChildrenCache;
- (void)invalidateSortedChildrenCache;
+ (void)invalidateSortedChildrenCacheOfPageWithID:(NSString *)uniqueID MOCPointer:(NSValue *)MOCValue;
+ (void)setCollectionIndexForPages:(NSArray *)pages;

- (NSArray *)sortedFromSet:(NSSet *)aSet withSortingType:(int)aSortType;

@end


@implementation KTPage (Children)

#pragma mark -
#pragma mark Basic Accessors

- (KTCollectionSortType)collectionSortOrder { return [self wrappedIntegerForKey:@"collectionSortOrder"]; }

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
	[newSortedChildren moveObjectAtIndex:[newSortedChildren indexOfObjectIdenticalTo:self] toIndex:index];
	[KTPage setCollectionIndexForPages:newSortedChildren];
	
	// Invalidate our parent's sortedChildren cache if it is manually sorted
	if ([parent collectionSortOrder] == KTCollectionUnsorted)
	{
		[parent invalidateSortedChildrenCache];
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
	NSParameterAssert(page);
	
	// To have a child page we must be a collection
	[self setBool:YES forKey:@"isCollection"];
	
	
	// If inserting a page into an manually sorted collection, place the page at the end of it
	if ([self collectionSortOrder] == KTCollectionUnsorted)
	{
		unsigned index = [[[self sortedChildren] lastObject] childIndex] + 1;
		[page setChildIndex:index];
	}
	
	
	// Attach the page to ourself and update the page cache
	[page setValue:self forKey:@"parent"];
	[self invalidateSortedChildrenCache];
}

/*	This method is remarkably simple since when you remove a page there is actually no need to update
 *	the childrens' -collectionIndex. They are ultimately still in the right overall order.
 */
- (void)removePage:(KTPage *)aPage
{
	// Remove the page and update the page cache
	[[self mutableSetValueForKey:@"children"] removeObject:aPage];
	[self invalidateSortedChildrenCache];
}

/*	Batch equivalent of the above method. It's significantly faster because we guarantee that the
 *	-sortedChildren cache will only be invalidated the once.
 */
- (void)removePages:(NSSet *)pages
{
	[[self mutableSetValueForKey:@"children"] minusSet:pages];
	[self invalidateSortedChildrenCache];
}

#pragma mark -
#pragma mark Sorted Children

/*	Returns our child pages in the correct ordering.
 *	The result is cached since calculating it is expensive for large collections.
 *	-sortedChildren should (fingers crossed!) be KVO-compliant.
 */
- (NSArray *)sortedChildren
{
	if (!mySortedChildrenCache)
	{
		NSSet *children = [self children];
		
		mySortedChildrenCache = [[self sortedFromSet:children withSortingType:KTCollectionSortUnspecified] copy];
	}
	
	return mySortedChildrenCache;
}


/*	Runs through the pages in the array and makes sure their -collectionIndex property matches
 *	the position in the array.
 *	This is a support method ONLY. It does NOT update and -sortedChildren caches.
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

- (void)invalidateSortedChildrenCache
{
	// Clear the cache
	[self willChangeValueForKey:@"sortedChildren"];
	[mySortedChildrenCache release];	mySortedChildrenCache = nil;
	[self didChangeValueForKey:@"sortedChildren"];
	
	// Register the operation as an undo.
	[[[[self managedObjectContext] undoManager] prepareWithInvocationTarget:[KTPage class]]
		invalidateSortedChildrenCacheOfPageWithID:[self uniqueID]
									   MOCPointer:[NSValue valueWithNonretainedObject:[self managedObjectContext]]];
}

/*	Undo operations on the cache HAVE to go through this method. This is because we can guarantee that the
 *	page ID is valid, but the original managed object might not be.
 *
 *	The MOC is not retained since that would create a cycle. Not a problem though, as deallocating the MOC
 *	will deallocate the undo manager as well.
 *
 *	We cannot invalidate the cache until the MOC has finished updating the properties of all affected pages.
 *	Thus, this method signs the collection up to the appropriate MOC notification for when changes
 *	are complete and that then invaldiates the cache. You'd think calling -processPendingChanges would work
 *	but the MOC seems to ignore it during undo/redo.
 */
+ (void)invalidateSortedChildrenCacheOfPageWithID:(NSString *)uniqueID MOCPointer:(NSValue *)MOCValue
{
	NSManagedObjectContext *MOC = [MOCValue nonretainedObjectValue];
	KTPage *page = [MOC pageWithUniqueID:uniqueID];
	OBASSERT(page);
	
	
	[[NSNotificationCenter defaultCenter] addObserver:page
											 selector:@selector(invalidateSortedChildrenCacheAfterUndoOrRedo:)
												 name:NSManagedObjectContextObjectsDidChangeNotification
											   object:MOC];
	
	[page retain];	// NSNotificationCenter won't retain page, so we do. It is released upon the notification.
}

- (void)invalidateSortedChildrenCacheAfterUndoOrRedo:(NSNotification *)notification
{
	// Clear the cache
	[self invalidateSortedChildrenCache];
	
	// We're only interested in the notification the once, so stop observing it
	[[NSNotificationCenter defaultCenter] removeObserver:self
												    name:[notification name]
												  object:[notification object]];
	
	[self release];	// Balances the retain when signing up to the notification.
}

#pragma mark debug

#ifdef DEBUG

- (id)valueForUndefinedKey:(NSString *)key
{
	if ([key isEqualToString:@"ordering"])
	{
		OBASSERT_NOT_REACHED("Please don't use -ordering on pages");
	}
	
	return [super valueForUndefinedKey:key];
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
	if ([key isEqualToString:@"ordering"])
	{
		OBASSERT_NOT_REACHED("Please don't use -ordering on pages");
	}
	else
	{
		[super setValue:value forUndefinedKey:key];
	}
}

#endif

#pragma mark -
#pragma mark Page Hierarchy Queries

- (KTPage *)parent { return [self wrappedValueForKey:@"parent"]; }

- (KTPage *)root 
{
	return [self valueForKeyPath:@"documentInfo.root"];
}

- (BOOL)isRoot
{
	BOOL result = (self == [self root]);
	return result;
}

- (KTPage *)parentOrRoot
{
	KTPage *result = [self parent];
	if (nil == result)
	{
		result = self;
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

- (NSIndexPath *)indexPathFromRoot;
{
	NSIndexPath *result = nil;
	
	KTPage *parent = [self parent];
	if (parent)							// Querying root should yield a nil path
	{
		unsigned index = [[parent sortedChildren] indexOfObjectIdenticalTo:self];
		OBASSERT(index != NSNotFound);
		
		NSIndexPath *parentPath = [parent indexPathFromRoot];
		if (parentPath)
		{
			result = [parentPath indexPathByAddingIndex:index];

		}
		else
		{
			result = [NSIndexPath indexPathWithIndex:index];
		}
	}
	
	return result;
}

#pragma mark -
#pragma mark To move into Index category

- (NSSet *)childrenInIndexSet
{
	NSSet *originalSet = [self children];
	NSMutableSet *visibleChildren = [NSMutableSet setWithSet:originalSet];	// stop "Collection ... was mutated while being enumerated" error
	NSEnumerator *theEnum = [originalSet objectEnumerator];
	KTPage *aPage;
	
	while (nil != (aPage = [theEnum nextObject]) )
	{
		if (![aPage includeInIndexAndPublish])
		{
			[visibleChildren removeObject:aPage];
		}
	}
	return visibleChildren;
}

- (NSArray *)sortedChildrenInIndex;
{
	return [self sortedFromSet:[self childrenInIndexSet] withSortingType:KTCollectionSortUnspecified];
}

/*!	Sorts the set of pages.  We factor it out so we can also get a sorted sub-set of children
*/
- (NSArray *)sortedFromSet:(NSSet *)aSet withSortingType:(int)aSortType
{
	if (0 == [aSet count])	// Empty?  No use in sorting
	{
		return [NSArray array];
	}
	NSArray *descriptors = nil;
	
	KTCollectionSortType sortType = aSortType;
	if (KTCollectionSortUnspecified == aSortType)
	{
		sortType = [self integerForKey:@"collectionSortOrder"];
	}
	
	switch (sortType)
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
			descriptors = [NSSortDescriptor unsortedPagesSortDescriptors];	// use the "childIndex" values
			break;
	}
	
	[self lockPSCAndMOC];
	NSArray *result = [[aSet allObjects] sortedArrayUsingDescriptors:descriptors];
	[self unlockPSCAndMOC];
	
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
		[titlesArray addObject:[child wrappedValueForKey:@"titleHTML"]];
	}
	[titlesArray sortUsingSelector:@selector(caseInsensitiveCompare:)];
	int result = [titlesArray indexOfObject:sortableTitle];
	
	//LOG((@"return proposed child drop index: %i sortedArray: %@", result, sortedArray));
	return result;
}

@end
