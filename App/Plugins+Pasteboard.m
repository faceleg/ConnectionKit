//
//  KTPage+Pasteboard.m
//  Marvel
//
//  Created by Mike on 29/12/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTPage.h"

#import "BDAlias.h"
#import "KTAbstractElement.h"
#import "KTMediaContainer+Pasteboard.h"
#import "KTMediaManager.h"
#import "KTPasteboardArchiving.h"

#import "NSEntityDescription+KTExtensions.h"


@interface KTPluginIDPasteboardRepresentation : NSObject <NSCoding>
{
	NSString *myPluginID;
	NSString *myPluginEntity;
}

- (id)initWithPlugin:(KTAbstractElement *)plugin;

- (NSString *)pluginID;
- (NSString *)pluginEntity;

@end


@implementation KTPluginIDPasteboardRepresentation

- (id)initWithPlugin:(KTAbstractElement *)plugin
{
	[super init];
	
	myPluginID = [[plugin uniqueID] copy];
	myPluginEntity = [[plugin entity] name];
	
	return self;
}

- (void)dealloc
{
	[myPluginID release];
	[myPluginEntity release];
	
	[super dealloc];
}

- (NSString *)pluginID { return myPluginID; }

- (NSString *)pluginEntity { return myPluginEntity; }

- (id)initWithCoder:(NSCoder *)decoder
{
	id result = [super init];
	
	myPluginID = [[decoder decodeObjectForKey:@"ID"] copy];
	myPluginEntity = [[decoder decodeObjectForKey:@"entity"] copy];
	
	return result;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:[self pluginID] forKey:@"ID"];
	[encoder encodeObject:[self pluginEntity] forKey:@"entity"];
}

@end


#pragma mark -


@implementation KTAbstractElement (Pasteboard)

+ (NSSet *)keysToIgnoreForPasteboardRepresentation
{
	return [NSSet setWithObjects:@"root", [self extensiblePropertiesDataKey], @"uniqueID", nil];
}

/*	We return a dictionary of our properties. However, media and page objects stored weakly by their ID must
 *	be converted to special NSCoder-compatible types.
 */
- (id <NSCoding>)pasteboardRepresentation
{
	// Start with our extensible properties
	NSDictionary *extensibleProperties = [self extensibleProperties];
	NSMutableDictionary *buffer = [NSMutableDictionary dictionaryWithDictionary:extensibleProperties];
	
	
	// Convert any pages into their id-only representation
	NSEnumerator *keysEnumerator = [[NSDictionary dictionaryWithDictionary:buffer] keyEnumerator];
	id aKey;
	while (aKey = [keysEnumerator nextObject])
	{
		id anObject = [buffer objectForKey:aKey];
		if (![anObject conformsToProtocol:@protocol(NSCoding)])
		{
			id <NSCoding> pasteboardRep = [anObject IDOnlyPasteboardRepresentation];
			[buffer setObject:pasteboardRep forKey:aKey];
		}
	}
	
	
	// Add in all attributes and keys from the model. Ignor transient properties.
	NSArray *propertyKeys = [[[self entity] propertiesByNameOfClass:[NSPropertyDescription class]
										 includeTransientProperties:NO] allKeys];
	NSDictionary *properties = [self dictionaryWithValuesForKeys:propertyKeys];
	[buffer addEntriesFromDictionary:properties];
	
	
	// Special case: pages need their thumbnails copied
	if ([self isKindOfClass:[KTPage class]])
	{
		[buffer setValue:[(KTPage *)self thumbnail] forKey:@"thumbnail"];
		[buffer setValue:[(KTPage *)self customSiteOutlineIcon] forKey:@"customSiteOutlineIcon"];
	}
	
	
	// Ignore keys us or our subclasses don't want archived
	NSSet *ignoredKeys = [[self class] keysToIgnoreForPasteboardRepresentation];
	[buffer removeObjectsForKeys:[ignoredKeys allObjects]];
	
	
	// Turn any managed objects into their pasteboard representation
	keysEnumerator = [[NSDictionary dictionaryWithDictionary:buffer] keyEnumerator];
	while (aKey = [keysEnumerator nextObject])
	{
		id anObject = [buffer objectForKey:aKey];
		
		BOOL objectIsNSCodingCompliant = [anObject conformsToProtocol:@protocol(NSCoding)];
		if ([anObject isKindOfClass:[NSSet class]] && ![[anObject anyObject] conformsToProtocol:@protocol(NSCoding)])
		{
			objectIsNSCodingCompliant = NO;
		}
		
		if (!objectIsNSCodingCompliant)
		{
			id <NSCoding> pasteboardRepObject = [anObject valueForKey:@"pasteboardRepresentation"];
			[buffer setObject:pasteboardRepObject forKey:aKey];
		}
	}
	
	
	return [NSDictionary dictionaryWithDictionary:buffer];
}

- (id <NSCoding>)IDOnlyPasteboardRepresentation
{
	id <NSCoding> result = [[[KTPluginIDPasteboardRepresentation alloc] initWithPlugin:self] autorelease];
	return result;
}

@end


#pragma mark -


@interface KTPage (Private)
+ (KTPage *)_insertNewPageWithParent:(KTPage *)parent pluginIdentifier:(NSString *)pluginIdentifier;
@end


@implementation KTPage (Pasteboard)

/*	There are several relationships we don't want archived
 */
+ (NSSet *)keysToIgnoreForPasteboardRepresentation
{
	static NSSet *sIgnoredKeys;
	
	if (!sIgnoredKeys)
	{
		NSMutableSet *result = [NSMutableSet setWithSet:[super keysToIgnoreForPasteboardRepresentation]];
		
		NSSet *myIgnoredKeys = [NSSet setWithObjects:@"master",
													 @"parent",
													 @"childIndex",
													 @"plugins",
													 @"documentInfo",
													 @"isStale",
													 @"publishedPath", nil];
		[result unionSet:myIgnoredKeys];
		sIgnoredKeys = [result copy];
	}
	
	return sIgnoredKeys;
}

+ (KTPage *)pageWithPasteboardRepresentation:(NSDictionary *)archive parent:(KTPage *)parent
{
	OBPRECONDITION(archive && [archive isKindOfClass:[NSDictionary class]]);
	OBPRECONDITION(parent);
	
	
	// Create a basic page
	NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithDictionary:archive];
	KTPage *result = [self _insertNewPageWithParent:parent
								   pluginIdentifier:[archive objectForKey:@"pluginIdentifier"]];
	[attributes removeObjectForKey:@"pluginIdentifier"];
	
	
	// Set up our pagelets
	NSMutableSet *pagelets = [result mutableSetValueForKey:@"pagelets"];
	NSSet *archivedPagelets = [archive objectForKey:@"pagelets"];
	NSEnumerator *pageletsEnumerator = [archivedPagelets objectEnumerator];
	NSDictionary *anArchivedPagelet;
	while (anArchivedPagelet = [pageletsEnumerator nextObject])
	{
		KTPagelet *pagelet = [KTPagelet pageletWithPasteboardRepresentation:anArchivedPagelet page:result];
		[pagelets addObject:pagelet];
	}
	
	
	// Set up the children
	NSMutableSet *children = [result mutableSetValueForKey:@"children"];
	NSEnumerator *pagesEnumerator = [[archive objectForKey:@"children"] objectEnumerator];
	NSDictionary *anArchivedPage;
	while (anArchivedPage = [pagesEnumerator nextObject])
	{
		KTPage *page = [KTPage pageWithPasteboardRepresentation:anArchivedPage parent:result];
		[children addObject:page];
	}
	
	
	// Prune away any properties no longer needing to be set
	NSArray *relationships = [[[result entity] relationshipsByName] allKeys];
	[attributes removeObjectsForKeys:relationships];
	[attributes removeObjectsForKeys:[[self keysToIgnoreForPasteboardRepresentation] allObjects]];
	[attributes removeObjectForKey:@"fileName"];	// Handled below
	
	
	// Convert Media and PluginIdentifiers back into real objects
	NSEnumerator *attributesEnumerator = [[NSDictionary dictionaryWithDictionary:attributes] keyEnumerator];
	id aKey;
	while (aKey = [attributesEnumerator nextObject])
	{
		id anObject = [attributes objectForKey:aKey];
		
		if ([anObject isKindOfClass:[KTMediaContainerPasteboardRepresentation class]])
		{
			NSString *mediaPath = [[(KTMediaContainerPasteboardRepresentation *)anObject alias] fullPath];
			KTMediaContainer *mediaContainer = [[result mediaManager] mediaContainerWithPath:mediaPath];
			[attributes setObject:mediaContainer forKey:aKey];
		}
		else if ([anObject isKindOfClass:[KTPluginIDPasteboardRepresentation class]])
		{
			// TODO: Properly handle plugin IDs
			[attributes removeObjectForKey:aKey];
		}
	}
	
	
	// Set the attributes. MUST set all values or some non-optional properties may be ignored. BUGSID:28711
	[result setValuesForKeysWithDictionary:attributes setAllValues:YES];
			
	
	// Give the page a decent filename
	NSString *suggestedFileName = [result suggestedFileName];
	[result setFileName:suggestedFileName];
	
	
	// Wake up the page
	[result awakeFromBundleAsNewlyCreatedObject:NO];
	
	
	return result;
}

@end


#pragma mark -


@interface KTPagelet (Private)
+ (KTPagelet *)_insertNewPageletWithPage:(KTPage *)page
						pluginIdentifier:(NSString *)pluginIdentifier
								location:(KTPageletLocation)location;
@end


@implementation KTPagelet (Pasteboard)

/*	Ignore our page relationship, the page will set it for us
 */
+ (NSSet *)keysToIgnoreForPasteboardRepresentation
{
	NSMutableSet *result = [NSMutableSet setWithSet:[super keysToIgnoreForPasteboardRepresentation]];
	[result addObject:@"page"];
	return result;
}

+ (KTPagelet *)pageletWithPasteboardRepresentation:(NSDictionary *)archive page:(KTPage *)page
{
	OBPRECONDITION(archive && [archive isKindOfClass:[NSDictionary class]]);
	OBPRECONDITION(page);	
	
	
	// Create a basic pagelet
	NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithDictionary:archive];
	
	KTPagelet *result = [self _insertNewPageletWithPage:page
									  pluginIdentifier:[archive objectForKey:@"pluginIdentifier"]
											  location:[archive integerForKey:@"location"]];
	
	[attributes removeObjectForKey:@"pluginIdentifier"];
	[attributes removeObjectForKey:@"location"];
	
	
	// Prune away any properties no longer needing to be set
	NSArray *relationships = [[[result entity] relationshipsByName] allKeys];
	[attributes removeObjectsForKeys:relationships];
	[attributes removeObjectsForKeys:[[self keysToIgnoreForPasteboardRepresentation] allObjects]];
	
	
	// Convert Media and PluginIdentifiers back into real objects
	NSEnumerator *attributesEnumerator = [[NSDictionary dictionaryWithDictionary:attributes] keyEnumerator];
	id aKey;
	while (aKey = [attributesEnumerator nextObject])
	{
		id anObject = [attributes objectForKey:aKey];
		
		if ([anObject isKindOfClass:[KTMediaContainerPasteboardRepresentation class]])
		{
			NSString *mediaPath = [[(KTMediaContainerPasteboardRepresentation *)anObject alias] fullPath];
			KTMediaContainer *mediaContainer = [[result mediaManager] mediaContainerWithPath:mediaPath];
			[attributes setObject:mediaContainer forKey:aKey];
		}
		else if ([anObject isKindOfClass:[KTPluginIDPasteboardRepresentation class]])
		{
			// TODO: Properly handle plugin IDs
			[attributes removeObjectForKey:aKey];
		}
	}
	
	
	// Set the attributes
	[result setValuesForKeysWithDictionary:attributes setAllValues:YES];
	
	
	// Wake up the page
	[result awakeFromBundleAsNewlyCreatedObject:NO];
	
	
	return result;
}

@end
