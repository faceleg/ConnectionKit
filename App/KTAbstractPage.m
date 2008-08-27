//
//  KTAbstractPage.m
//  Marvel
//
//  Created by Mike on 28/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTAbstractPage.h"
#import "KTPage.h"

#import "KTDocumentInfo.h"
#import "KTHostProperties.h"
#import "KTHTMLParser.h"

#import "NSAttributedString+Karelia.h"
#import "NSBundle+KTExtensions.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSString+Karelia.h"
#import "NSString+KTExtensions.h"
#import "NSURL+Karelia.h"
#import "NSScanner+Karelia.h"

#import "Debug.h"


@interface KTPage (ChildrenPrivate)
- (void)invalidateSortedChildrenCache;
@end


@implementation KTAbstractPage

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
#pragma mark Title

- (void)setTitleHTML:(NSString *)value
{
	[self setWrappedValue:value forKey:@"titleHTML"];
	
	
	// The site structure has changed as a result of this
	[self postSiteStructureDidChangeNotification];
	
	
	// If the page hasn't been published yet, update the filename to match
	if ([self shouldUpdateFileNameWhenTitleChanges])
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
	NSString *result = [html stringByConvertingHTMLToPlainText];
	return result;
}

// We set attributed title, but since we're giving it plain text, it's just an attributed version of that.

- (void)setTitleText:(NSString *)value
{
	[self setTitleHTML:[value stringByEscapingHTMLEntities]];
}

// For bindings.  We can edit title if we aren't root;
- (BOOL)canEditTitle
{
	BOOL result = ![self isRoot];
	return result;
}

/*	These accessors are tacked on to 1.5. They should become a proper part of the model in 2.0
 */

- (BOOL)shouldUpdateFileNameWhenTitleChanges
{
	BOOL result;
	
	NSNumber *defaultResult = [self valueForUndefinedKey:@"shouldUpdateFileNameWhenTitleChanges"];
	if (defaultResult)
	{
		result = [defaultResult boolValue];
	}
	else
	{
		result = (![self publishedPath] && ![self publishedDataDigest]);
	}
	
	return result;
}

- (void)setShouldUpdateFileNameWhenTitleChanges:(BOOL)autoUpdate
{
	[self setValue:[NSNumber numberWithBool:autoUpdate] forUndefinedKey:@"shouldUpdateFileNameWhenTitleChanges"];
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

/*!	Given the page text, scan for all page ID references and convert to the proper relative links.
 */
- (NSString *)fixPageLinksFromString:(NSString *)originalString managedObjectContext:(NSManagedObjectContext *)context
{
	NSMutableString *buffer = [NSMutableString string];
	NSScanner *scanner = [NSScanner scannerWithRealString:originalString];
	while ( ![scanner isAtEnd] )
	{
		NSString *beforeLink = nil;
		BOOL found = [scanner scanUpToString:kKTPageIDDesignator intoString:&beforeLink];
		if (found)
		{
			[buffer appendString:beforeLink];
			if (![scanner isAtEnd])
			{
				[scanner scanString:kKTPageIDDesignator intoString:nil];
				NSString *idString = nil;
				BOOL foundNumber = [scanner scanCharactersFromSet:[KTPage uniqueIDCharacters]
													   intoString:&idString];
				if (foundNumber)
				{
					KTPage* thePage = [KTPage pageWithUniqueID:idString inManagedObjectContext:context];
					NSString *newPath = nil;
					if (thePage)
					{
						newPath = [[thePage URL] stringRelativeToURL:[self URL]];
					}
					
					if (!newPath) newPath = @"#";	// Fallback
					[buffer appendString:newPath];
				}
			}
		}
	}
	return [NSString stringWithString:buffer];
}

#pragma mark -
#pragma mark Staleness

- (BOOL)isStale { return [self wrappedBoolForKey:@"isStale"]; }

- (void)setIsStale:(BOOL)stale
{
	BOOL valueWillChange = (stale != [self boolForKey:@"isStale"]);
	
	if (valueWillChange)
	{
		[self setWrappedBool:stale forKey:@"isStale"];
	}
}

/*  For 1.5 we are having to fake these methods using extensible properties
 */
- (NSData *)publishedDataDigest
{
    return [self valueForUndefinedKey:@"publishedDataDigest"]; 
}

- (void)setPublishedDataDigest:(NSData *)digest
{
    [self setValue:digest forUndefinedKey:@"publishedDataDigest"];
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

@end
