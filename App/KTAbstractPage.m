//
//  KTAbstractPage.m
//  Marvel
//
//  Created by Mike on 28/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTAbstractPage.h"
#import "KTPage.h"

#import "KTHTMLParser.h"

#import "NSAttributedString+Karelia.h"
#import "NSBundle+KTExtensions.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSString+Karelia.h"
#import "NSString+KTExtensions.h"

#import "Debug.h"


@interface KTAbstractPage (PathsPrivate)
- (NSString *)_pathRelativeToSite;
@end


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

#pragma mark -
#pragma mark Initialisation

/*	As above, but uses a predicate to narrow down to a particular ID
 */
+ (id)pageWithUniqueID:(NSString *)ID inManagedObjectContext:(NSManagedObjectContext *)MOC
{
	id result = [MOC objectWithUniqueID:ID entityName:[self entityName]];
	return result;
}

/*	Generic creation method for all page types.
 */
+ (id)pageWithParent:(KTPage *)aParent entityName:(NSString *)entityName
{
	OBPRECONDITION(aParent);
	
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

/*	Only KTPages can be collections
 */
- (BOOL)isCollection { return NO; }

- (BOOL)isRoot
{
	BOOL result = ((id)self == [[self documentInfo] root]);
	return result;
}

- (KTDocumentInfo *)documentInfo { return [self wrappedValueForKey:@"documentInfo"]; }

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

#pragma mark -
#pragma mark Title

- (void)setTitleHTML:(NSString *)value
{
	[self setWrappedValue:value forKey:@"titleHTML"];
	
	
	// The site structure has changed as a result of this
	[self postSiteStructureDidChangeNotification];
	
	
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

- (NSString *)pageMainContentTemplate;	// instance method too for key paths to work in tiger
{
	static NSString *sPageTemplateString = nil;
	
	if (!sPageTemplateString)
	{
		NSString *path = [[NSBundle bundleForClass:[self class]] overridingPathForResource:@"KTPageMainContentTemplate" ofType:@"html"];
		NSData *data = [NSData dataWithContentsOfFile:path];
		sPageTemplateString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	}
	
	return sPageTemplateString;
}

- (NSString *)uniqueWebViewID
{
	NSString *result = [NSString stringWithFormat:@"ktpage-%@", [self uniqueID]];
	return result;
}

/*!	Return the HTML.
*/
- (NSString *)contentHTMLWithParserDelegate:(id)parserDelegate isPreview:(BOOL)isPreview;
{
	// Fallback to show problem
	NSString *result = @"[PAGE, UNABLE TO GET CONTENT HTML]";
	
	
	// Build the HTML
	KTHTMLParser *parser = [[KTHTMLParser alloc] initWithPage:self];
	[parser setDelegate:parserDelegate];
	
	if (isPreview) {
		[parser setHTMLGenerationPurpose:kGeneratingPreview];
	} else {
		[parser setHTMLGenerationPurpose:kGeneratingRemote];
	}
	
	result = [parser parseTemplate];
	[parser release];
	
	
	return result;
}

#pragma mark -
#pragma mark Notifications

/*	A convenience method for posting the kKTSiteStructureDidChangeNotification
 */
- (void)postSiteStructureDidChangeNotification;
{
	KTDocumentInfo *site = [self valueForKey:@"documentInfo"];
	[[NSNotificationCenter defaultCenter] postNotificationName:KTSiteStructureDidChangeNotification object:site];
}

#pragma mark -
#pragma mark KTWebPathsProtocol

/*	These methods are in KTAbstractPage.m to keep the compiler happy.
 *	They just call through where appropriate to the real methods in the +Paths category.
 */

- (NSURL *)absoluteURL { return [self publishedURL]; }

/*	The result of this method is cached until the path changes agan in some way from a -invalidatePathRelativeToSite
 *	method call. -_pathRelativeToSite will return the uncached path.
 */
- (NSString *)pathRelativeToSite
{
	NSString *result = [self wrappedValueForKey:@"pathRelativeToSite"];
	
	if (!result)
	{
		result = [self _pathRelativeToSite];
		[self setPrimitiveValue:result forKey:@"pathRelativeToSite"];
	}
	
	return result;
}

- (NSString *)pathRelativeTo:(id <KTWebPaths>)path2
{
	NSString *result = [[self pathRelativeToSite] URLPathRelativeTo:[path2 pathRelativeToSite]];
	// TODO:	Make sure the result has a trailing slash if necessary
	return result;
}

#pragma mark -
#pragma mark Debugging

- (id)valueForUndefinedKey:(NSString *)key
{
	if ([key isEqualToString:@"root"])
	{
		OBASSERT_NOT_REACHED("You should never call -root on a page.");
	}
	
	return [super valueForUndefinedKey:key];
}

@end
