//
//  KTAbstractPage.m
//  Marvel
//
//  Created by Mike on 28/02/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTAbstractPage.h"
#import "KTPage.h"

#import "KTSite.h"
#import "KTHostProperties.h"
#import "SVHTMLTemplateParser.h"
#import "SVSidebar.h"

#import "NSAttributedString+Karelia.h"
#import "NSBundle+KTExtensions.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSString+KTExtensions.h"
#import "NSURL+Karelia.h"
#import "NSScanner+Karelia.h"

#import "Debug.h"


@interface KTAbstractPage ()
@property(nonatomic, retain, readwrite) SVSidebar *sidebar;
@end


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
	
	[result setValue:[aParent valueForKey:@"site"] forKey:@"site"];
	
	
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

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    // Create a corresponding sidebar
    SVSidebar *sidebar = [NSEntityDescription insertNewObjectForEntityForName:@"Sidebar"
                                                       inManagedObjectContext:[self managedObjectContext]];
    
    [self setSidebar:sidebar];
}

#pragma mark Accessors

- (KTPage *)parent { return [self wrappedValueForKey:@"parent"]; }

/*	Only KTPages can be collections
 */
- (BOOL)isCollection { return NO; }

- (BOOL)isRoot
{
	BOOL result = ((id)self == [[self site] root]);
	return result;
}

- (BOOL)isDescendantOfPage:(KTAbstractPage *)aPotentialAncestor;
{
	KTPage *parent = [self parent];
	if (nil == parent)		// we are at the root node, so it can't be descended from the given node
	{
		return NO;
	}
	if (aPotentialAncestor == parent)
	{
		return YES;
	}
	return [parent isDescendantOfPage:aPotentialAncestor];
}

- (KTSite *)site { return [self wrappedValueForKey:@"site"]; }

- (KTMaster *)master
{
    SUBCLASSMUSTIMPLEMENT;
    return nil;
}

@dynamic sidebar;

#pragma mark -
#pragma mark Title

// For bindings.  We can edit title if we aren't root;
- (BOOL)canEditTitle
{
	BOOL result = ![self isRoot];
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

+ (NSCharacterSet *)uniqueIDCharacters
{
	static NSCharacterSet *result;
	
	if (!result)
	{
		result = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"] retain];
	}
	
	return result;
}

/*!	Return the HTML.
*/
- (NSString *)contentHTMLWithParserDelegate:(id)parserDelegate isPreview:(BOOL)isPreview;
{
	// Fallback to show problem
	NSString *result = @"[PAGE, UNABLE TO GET CONTENT HTML]";
	
	
	// Build the HTML
	SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc] initWithPage:self];
	[parser setDelegate:parserDelegate];
	
	if (isPreview) {
		[parser setHTMLGenerationPurpose:kGeneratingPreview];
	} else {
		[parser setHTMLGenerationPurpose:kGeneratingRemote];
	}
	
	result = [parser parseTemplate];
	[parser release];
	
	
	// Now that we have page contents in unicode, clean up to the desired character encoding.
	result = [result stringByEscapingCharactersOutOfCharset:[[self master] valueForKey:@"charset"]];
    
	if (![self isXHTML])	// convert /> to > for HTML 4.0.1 compatibility
	{
		result = [result stringByReplacing:@"/>" with:@">"];
	}
	
	
	return result;
}

- (BOOL)isXHTML
{
    SUBCLASSMUSTIMPLEMENT;
    return YES;
}

#pragma mark -
#pragma mark Meta tags

- (NSString *)metaDescription
{
	return [self valueForUndefinedKey:@"metaDescription"];
}

- (void)setMetaDescription:(NSString *)description
{
	[self setValue:description forUndefinedKey:@"metaDescription"];
}

- (NSString *)windowTitle
{
	return [self valueForUndefinedKey:@"windowTitle"];
}

- (void)setWindowTitle:(NSString *)wTitle
{
	[self setValue:wTitle forUndefinedKey:@"windowTitle"];
}

#pragma mark -
#pragma mark Comments

/*  http://wiki.js-kit.com/Admin-Guide#Importantattributes
 */
- (NSString *)JSKitPath
{
    NSString *result = [[self URL] path];
	if ( nil == result )
	{
		result = @"/";
	}
    return result;
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

@end
