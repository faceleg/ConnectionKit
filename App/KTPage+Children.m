//
//  KTPage+Collections.m
//  Marvel
//
//  Created by Mike on 30/01/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import "KTPage.h"

#import "KTSite.h"

#import "NSArray+Karelia.h"
#import "NSError+Karelia.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSSortDescriptor+Karelia.h"

#import "Debug.h"


@interface KTPage (ChildrenPrivate)

+ (void)setCollectionIndexForPages:(NSArray *)pages;

+ (NSPredicate *)includeInIndexAndPublishPredicate;
+ (NSSet *)sortedChildrenDependentChildrenKeys;

- (NSArray *)sortDescriptorsForCollectionSortType:(SVCollectionSortOrder)sortType ascending:(BOOL)ascending;
+ (NSArray *)unsortedPagesSortDescriptors;
+ (NSArray *)alphabeticalTitleTextSortDescriptorsAscending:(BOOL)ascending;
+ (NSArray *)dateCreatedSortDescriptorsAscending:(BOOL)ascending;
+ (NSArray *)dateModifiedSortDescriptorsAscending:(BOOL)ascending;


@end


#pragma mark -


@implementation KTPage (Children)

#pragma mark Basic Accessors

/*!	simple wrapper; defined for convenience of calling it.  Not optional property, so this should be OK.
*/
- (BOOL)isCollection	
{
	BOOL result = [[self wrappedValueForKey:@"isCollection"] boolValue];
	return result;		// not an optional property, so it's OK to convert to a non-object
}

- (void)setIsCollection:(BOOL)collection;
{
    [self willChangeValueForKey:@"isCollection"];
    [self setPrimitiveValue:NSBOOL(collection) forKey:@"isCollection"];
    [self didChangeValueForKey:@"isCollection"];
    
    // #93959
    [self setDatePublished:nil];
    [self recursivelyInvalidateURL:YES];
    
    // Regular pages can't take thumbnail from children. #93638
    if (!collection)
    {
        SVThumbnailType thumbType = [[self thumbnailType] intValue];
        if (thumbType == SVThumbnailTypeFirstChildItem ||
            thumbType == SVThumbnailTypeLastChildItem)
        {
            [self setThumbnailType:[NSNumber numberWithInt:SVThumbnailTypeNone]];
        }
    }
}

- (BOOL)willPublishAsCollection; { return [self isCollection]; }
- (void)setWillPublishAsCollection:(BOOL)collection; { }
+ (NSSet *) keyPathsForValuesAffectingWillPublishAsCollection;
{
    return [NSSet setWithObject:@"isCollection"];
}

#pragma mark Children

@dynamic childItems;
- (NSSet *)childItems
{
    [self willAccessValueForKey:@"childItems"];
    NSSet *result = [self primitiveValueForKey:@"childItems"];
    [self didAccessValueForKey:@"childItems"];
    return result;
}

#pragma mark Sorting Properties

@dynamic collectionSortOrder;
- (void)setCollectionSortOrder:(NSNumber *)sorting
{
	// When switching TO manual sorting ensure child indexes are up-to-date
    // Should do this first. #111644
	if ([sorting integerValue] == SVCollectionSortManually)
	{
		[KTPage setCollectionIndexForPages:[self sortedChildren]];
	}
    
	[self willChangeValueForKey:@"collectionSortOrder"];
	[self setPrimitiveValue:sorting forKey:@"collectionSortOrder"];
    [self didChangeValueForKey:@"collectionSortOrder"];
}

- (BOOL)isSortedChronologically;
{
    SVCollectionSortOrder sorting = [[self collectionSortOrder] integerValue];
    BOOL result = (sorting == SVCollectionSortByDateCreated || sorting == SVCollectionSortByDateModified);
    return result;
}

@dynamic collectionSortAscending;

#pragma mark Sorted Children

/*	Returns our child pages in the correct ordering.
 *	The result is cached since calculating it is expensive for large collections.
 *	-sortedChildren is KVO-compliant.
 */
- (NSArray *)sortedChildren
{
	NSArray *result = [self childrenWithSorting:SVCollectionSortOrderUnspecified
                                 ascending:[[self collectionSortAscending] boolValue]
                                   inIndex:NO];
	
	return result;
}

/*	-collectionIndex and -setCollectionIndex are private methods that -sortedChildren uses internally.
 *	The public API for this is the -moveChild:toIndex: method which calls -setCollectionIndex on all affected siblings
 *	and updates the parent's -sortedChildren cache.
 *
 *	Calling this method upon a page with no parent, or within a sorted collection will raise an exception.
 */

- (void)moveChild:(SVSiteItem *)child toIndex:(NSUInteger)index;
{	
	NSAssert1(self, @"-%@ called upon page with not in a collection", NSStringFromSelector(_cmd));
	NSAssert1(([[self collectionSortOrder] integerValue] == SVCollectionSortManually),
              @"-%@ called upon page in a sorted collection", NSStringFromSelector(_cmd));
	
	// Change our index and that of any affected siblings
	NSMutableArray *newSortedChildren = [NSMutableArray arrayWithArray:[self sortedChildren]];
	unsigned whereSelfInParent = [newSortedChildren indexOfObjectIdenticalTo:child];
	
	// Check that we were actually found.  Mystery case 34642.  
	if (whereSelfInParent != NSNotFound && index <= [newSortedChildren count])
	{
		[newSortedChildren moveObjectAtIndex:whereSelfInParent toIndex:index];
		[KTPage setCollectionIndexForPages:newSortedChildren];
	}
	else
	{
		NSLog(@"%@ trying to move from %d to %d in an array of %d elements",
              NSStringFromSelector(_cmd),
              whereSelfInParent,
              index,
              [newSortedChildren count]);
	}
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

#pragma mark Sorting Support

/*	Public support method that will return the receiver's children with the specified sorting.
 *	If ignoreDrafts==YES then UNPUBLISHED drafts are filtered out.
 *	Not cached like -sortedChildren.
*/
- (NSArray *)childrenWithSorting:(SVCollectionSortOrder)sortType
                       ascending:(BOOL)ascending
                         inIndex:(BOOL)ignoreDrafts;
{
	NSArray *result = [[self childItems] allObjects];
	
	
	// Filter out drafts if requested
	if (ignoreDrafts)
	{
		result = [result filteredArrayUsingPredicate:[[self class] includeInIndexAndPublishPredicate]];
	}
	
	
	// Sometimes there's no point in sorting
	if ([result count] > 1)
	{		
		// Do the sort
		NSArray *sortDescriptors = [self sortDescriptorsForCollectionSortType:sortType ascending:ascending];
        
		result = [result sortedArrayUsingDescriptors:sortDescriptors];
	}	
	
	
	return result;
}
		
+ (NSPredicate *)includeInIndexAndPublishPredicate
{
	static NSPredicate *result;
	if (!result)
	{
		result = [[NSPredicate predicateWithFormat:@"shouldIncludeInIndexes != NO"] retain];
	}
	
	return result;
}

- (NSArray *)childItemsSortDescriptors;
{
    return [self
            sortDescriptorsForCollectionSortType:[[self collectionSortOrder] intValue]
            ascending:[[self collectionSortAscending] boolValue]];
}
+ (NSSet *)keyPathsForValuesAffectingChildItemsSortDescriptors;
{
    return [NSSet setWithObjects:@"collectionSortOrder", @"collectionSortAscending", nil];
}

/*	Translates between KTCollectionSortType & the right sort descriptor objects
 */
- (NSArray *)sortDescriptorsForCollectionSortType:(SVCollectionSortOrder)sortType ascending:(BOOL)ascending;
{
	if (sortType == SVCollectionSortOrderUnspecified)
    {
        sortType = [[self collectionSortOrder] integerValue];
    }
    
    return [[self class] sortDescriptorsForCollectionOrder:sortType ascending:ascending];
}

+ (NSArray *)sortDescriptorsForCollectionOrder:(SVCollectionSortOrder)sortType ascending:(BOOL)ascending;
{
    NSArray *result;
	switch (sortType)
	{
		case SVCollectionSortAlphabetically:
			result = [KTPage alphabeticalTitleTextSortDescriptorsAscending:ascending];
			break;
		case SVCollectionSortByDateCreated:
			result = [KTPage dateCreatedSortDescriptorsAscending:ascending];
			break;
		case SVCollectionSortByDateModified:
			result = [KTPage dateModifiedSortDescriptorsAscending:ascending];
			break;
		default:
			result = [NSArray array];
			break;
	}
	
    // Fallback to sorting by custom order, and then ID. #139630
	result = [result arrayByAddingObjectsFromArray:[KTPage unsortedPagesSortDescriptors]];  // use the "childIndex" values
    return result;
}

+ (NSArray *)unsortedPagesSortDescriptors;
{
	static NSArray *result;
	
	if (!result)
	{
		NSSortDescriptor *orderingDescriptor = [[NSSortDescriptor alloc] initWithKey:@"childIndex" ascending:YES];
        NSSortDescriptor *fallbackDescriptor = [[NSSortDescriptor alloc] initWithKey:@"identifier" ascending:YES];
		result = [[NSArray alloc] initWithObjects:orderingDescriptor, fallbackDescriptor, nil];
        [fallbackDescriptor release];
		[orderingDescriptor release];
	}
	
	return result;
}

+ (NSArray *)alphabeticalTitleTextSortDescriptorsAscending:(BOOL)ascending;
{
    NSSortDescriptor *orderingDescriptor = [[NSSortDescriptor alloc] initWithKey:@"title"
                                                                       ascending:ascending
                                                                        selector:@selector(caseInsensitiveCompare:)];
    
	NSArray *result = [NSArray arrayWithObject:orderingDescriptor];
    [orderingDescriptor release];
	
	return result;
}

+ (NSArray *)dateCreatedSortDescriptorsAscending:(BOOL)ascending;
{
	NSArray *result = nil;
	
	if (!result)
	{
		NSSortDescriptor *orderingDescriptor = [[NSSortDescriptor alloc] initWithKey:@"creationDate"
                                                                           ascending:ascending];
		result = [[[NSArray alloc] initWithObject:orderingDescriptor] autorelease];
		[orderingDescriptor release];
	}
	
	return result;
}

+ (NSArray *)dateModifiedSortDescriptorsAscending:(BOOL)ascending;
{
	NSArray *result = nil;
	
	if (!result)
	{
		NSSortDescriptor *orderingDescriptor = [[NSSortDescriptor alloc] initWithKey:@"modificationDate" 
                                                                           ascending:ascending];
		result = [[[NSArray alloc] initWithObject:orderingDescriptor] autorelease];
		[orderingDescriptor release];
	}
	
	return result;
}

#pragma mark Page Hierarchy Queries

- (BOOL)isRootPage; // like NSTreeNode, the root page is defined to be one with no parent. This is just a convenience around that
{
    BOOL result = ([self parentPage] == nil);
    return result;
}

- (KTPage *)rootPage;   // searches up the tree till it finds a page with no parent
{
    KTPage *result = ([self isRootPage] ? self : [[self parentPage] rootPage]);
    return result;
}

- (KTPage *)parentOrRoot
{
	KTPage *result = [self parentPage];
	if (nil == result)
	{
		result = self;
	}
	return result;
}

/*	Every page bar root should have a parent.
 */
- (BOOL)validateParentPage:(KTPage **)page error:(NSError **)outError;
{
	if ([self isRoot])
    {
        return YES;
    }
    else
    {
        return [super validateParentPage:page error:outError];
    }
}

- (BOOL)hasChildren
{
	NSSet *children = [self childItems];
	BOOL result = ([children count] > 0);
	return result;
}

#pragma mark Navigation Arrows

@dynamic navigationArrowsStyle;

#pragma mark -
#pragma mark Should probably be deprecated

+ (NSArray *)orderingSortDescriptors
{
	static NSArray *result;
	
	if (!result)
	{
		NSSortDescriptor *orderingDescriptor = [[NSSortDescriptor alloc] initWithKey:@"ordering" ascending:YES];
		result = [[NSArray alloc] initWithObjects:orderingDescriptor, nil];
		[orderingDescriptor release];
	}
	
	return result;
}

- (int)proposedOrderingForProposedChildWithTitle:(NSString *)aTitle
{
	// we'll add _zzz to the end of the title so that it's hopefully different
	// just in case the list already has seven things called "Untitled Page"
	NSString *sortableTitle = [aTitle stringByAppendingString:@"_zzz"];
	
	NSMutableArray *titlesArray = [NSMutableArray array];
	[titlesArray addObject:sortableTitle];
	
    NSSet *children = [self childItems];
	
	KTPage *child;
	for ( child in children )
	{
		[titlesArray addObject:[child title]];
	}
	[titlesArray sortUsingSelector:@selector(caseInsensitiveCompare:)];
	int result = [titlesArray indexOfObject:sortableTitle];
	
	//LOG((@"return proposed child drop index: %i sortedArray: %@", result, sortedArray));
	return result;
}

@end
