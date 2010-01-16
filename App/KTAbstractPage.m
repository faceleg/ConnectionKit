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
#import "SVMutableStringHTMLContext.h"
#import "SVSidebar.h"
#import "SVTitleBox.h"

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
		[aParent addChildItem:(KTPage *)result];
	}
	else
	{
		[result setValue:aParent forKey:@"parentPage"];
	}
	
	
	return result;
}

- (void)awakeFromInsert
{
    [super awakeFromInsert];
	
	[self setPrimitiveValue:[NSString shortUUIDString] forKey:@"uniqueID"];
    
    // Create a corresponding sidebar
    SVSidebar *sidebar = [NSEntityDescription insertNewObjectForEntityForName:@"Sidebar"
                                                       inManagedObjectContext:[self managedObjectContext]];
    
    [self setSidebar:sidebar];
}

#pragma mark Identifier

@dynamic uniqueID;

- (NSString *)identifier { return [self uniqueID]; }

#pragma mark Child Pages

/*	All this stuff is only relevant to KTPage, but it makes it so much more convenient to declare them at the KTAbstractPage level.
 */
- (NSSet *)archivePages { return nil; }
- (BOOL)isCollection { return NO; }

@dynamic parentPage;

- (BOOL)isRoot
{
	BOOL result = ((id)self == [[self site] root]);
	return result;
}

#pragma mark Other Relationships

- (KTSite *)site { return [self wrappedValueForKey:@"site"]; }

- (KTMaster *)master
{
    SUBCLASSMUSTIMPLEMENT;
    return nil;
}

@dynamic sidebar;

#pragma mark Title

@dynamic title;

- (void)setTitleWithString:(NSString *)title;
{
    SVTitleBox *text = [self title];
    if (!text)
    {
        text = [NSEntityDescription insertNewObjectForEntityForName:@"PageTitle" inManagedObjectContext:[self managedObjectContext]];
        [self setTitle:text];
    }
    [text setText:title];
}

// For bindings.  We can edit title if we aren't root;
- (BOOL)canEditTitle
{
	BOOL result = ![self isRoot];
	return result;
}

- (NSString *)titleHTMLString
{
    return [[self title] textHTMLString];
}

- (NSString *)titleString;
{
	return [[self title] text];
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

- (void)writeHTML;  // prepares the current HTML context (XHTML, encoding etc.), then writes to it
{
	// Build the HTML
    [[SVHTMLContext currentContext] setXHTML:[self isXHTML]];
    [[SVHTMLContext currentContext] setEncoding:[[[self master] valueForKey:@"charset"] encodingFromCharset]];
    
	SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc] initWithPage:self];
    [parser parseIntoHTMLContext:[SVHTMLContext currentContext]];
    [parser release];
}

- (NSString *)HTMLString;   // creates a temporary HTML context and calls -writeHTML
{
    SVMutableStringHTMLContext *context = [[SVMutableStringHTMLContext alloc] init];
    [context setCurrentPage:self];
    
    [context push];
    [self writeHTML];
    [context pop];
    
    NSString *result = [context markupString];
    [context release];
    return result;
}

- (BOOL)isXHTML
{
    SUBCLASSMUSTIMPLEMENT;
    return YES;
}

- (NSString *)commentsTemplate	// instance method too for key paths to work in tiger
{
	static NSString *result;
	
	if (!result)
	{
		NSString *templatePath = [[NSBundle mainBundle] pathForResource:@"KTCommentsTemplate" ofType:@"html"];
		result = [[NSString alloc] initWithContentsOfFile:templatePath];
	}
	
	return result;
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

#pragma mark Operations

/*	As the title suggests, performs the selector upon either self or the delegate. Delegate takes preference.
 *	At present the recursive flag is only used by pages.
 */
- (void)makeSelfOrDelegatePerformSelector:(SEL)selector
							   withObject:(void *)anObject
								 withPage:(KTPage *)page
								recursive:(BOOL)recursive
{
	if ([self isDeleted])
	{
		return; // stop these calls if we're not really there any more
	}
	
	if ([self respondsToSelector:selector])
	{
		[self performSelector:selector withObject:(id)anObject withObject:page];
	}
}

- (NSString *)spotlightHTML
{
	NSString *result = nil;
	
	// TODO: Figure a nice way to get reasonable plain text out of our body
	if ( nil == result )
	{
		result = @"";
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
    return [self extensiblePropertyForKey:@"publishedDataDigest"]; 
}

- (void)setPublishedDataDigest:(NSData *)digest
{
    [self willChangeValueForKey:@"publishedDataDigest"];
    [self setExtensibleProperty:digest forKey:@"publishedDataDigest"];
    [self didChangeValueForKey:@"publishedDataDigest"];
}

@end


#pragma mark -


@implementation KTAbstractPage (Deprecated)

#pragma mark Title

+ (NSSet *)keyPathsForValuesAffectingTitleHTMLString
{
    return [NSSet setWithObject:@"title.textHTMLString"];
}

- (NSString *)titleText	// get title, but without attributes
{
	return [self titleString];
}

- (void)setTitleText:(NSString *)value
{
	[self setTitleWithString:value];
}

+ (NSSet *)keyPathsForValuesAffectingTitleText
{
    return [NSSet setWithObject:@"title.textHTMLString"];
}

@end
