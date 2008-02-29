//
//  KTAbstractPage.m
//  Marvel
//
//  Created by Mike on 28/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTAbstractPage.h"
#import "KTPage.h"

#import "NSAttributedString+Karelia.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSString+Karelia.h"

#import "Debug.h"


@interface KTPage (ChildrenPrivate)
- (void)invalidateSortedChildrenCache;
@end


@implementation KTAbstractPage

+ (NSString *)extensiblePropertiesDataKey { return nil; }

+ (NSString *)entityName { return @"AbstractPage"; }

/*	Picks out all the pages correspoding to self's entity
 */
+ (NSArray *)allPagesInManagedObjectContext:(NSManagedObjectContext *)MOC
{
	NSArray *result = [MOC allObjectsWithEntityName:[self entityName] error:NULL];
	return result;
}

/*	Generic creation method for all page types.
 */
+ (id)pageWithParent:(KTPage *)aParent entityName:(NSString *)entityName
{
	NSParameterAssert(aParent);
	
	// Create the page
	KTAbstractPage *result = [NSEntityDescription insertNewObjectForEntityForName:entityName
														   inManagedObjectContext:[aParent managedObjectContext]];
	
	[result setValue:[aParent valueForKey:@"documentInfo"] forKey:@"documentInfo"];
	
	
	// How the page is connected to its parent depends on the class type. KTPage needs special handling for the cache.
	if ([result isKindOfClass:[KTPage class]])
	{
		[aParent addPage:(KTPage *)result];
	}
	else
	{
		[result setValue:aParent forKey:@"parent"];
	}
	
	
	return result;
}

- (KTPage *)parent { return [self wrappedValueForKey:@"parent"]; }

- (KTPage *)root 
{
	return [self valueForKeyPath:@"documentInfo.root"];
}

/*	Only KTPages can be collections
 */
- (BOOL)isCollection { return NO; }

- (BOOL)isRoot
{
	BOOL result = ((id)self == [self root]);
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
#pragma mark HTML

- (NSString *)contentHTMLWithParserDelegate:(id)parserDelegate isPreview:(BOOL)isPreview isArchives:(BOOL)isArchives;
{
	SUBCLASSMUSTIMPLEMENT;
	return nil;
}

@end
