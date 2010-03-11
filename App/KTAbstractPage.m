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
#import "SVHTMLContext.h"
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


@implementation KTAbstractPage

+ (NSString *)entityName { return @"AbstractPage"; }

/*	Picks out all the pages correspoding to self's entity
 */
+ (NSArray *)allPagesInManagedObjectContext:(NSManagedObjectContext *)MOC
{
	NSArray *result = [MOC fetchAllObjectsForEntityForName:[self entityName] error:NULL];
	return result;
}

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
	BOOL result = ((id)self == [[self site] rootPage]);
	return result;
}

#pragma mark HTML

+ (NSCharacterSet *)uniqueIDCharacters
{
	static NSCharacterSet *result;
	
	if (!result)
	{
		result = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"] retain];
	}
	
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

@end
