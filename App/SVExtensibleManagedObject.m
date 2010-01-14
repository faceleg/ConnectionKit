//
//  SVExtensibleManagedObject.m
//  KTComponents
//
//  Created by Terrence Talbot on 6/22/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "SVExtensibleManagedObject.h"

#import "KTAbstractPage.h"
#import "KTDocument.h"
#import "KTExtensiblePluginPropertiesArchivedObject.h"

#import "NSArray+Karelia.h"
#import "NSDocumentController+KTExtensions.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSObject+KTExtensions.h"

#import "Debug.h"


@implementation SVExtensibleManagedObject

#pragma mark -
#pragma mark Plugin Properties

// Disable support for extensible properties
- (BOOL)canStoreExtensiblePropertyForKey:(NSString *)key { return NO; }

/*	During a Save As operation, KTExtensiblePluginPropertiesArchivedObject cannot be unarchived. We want to hang
 *	on to them, but not present them to the user.
 */
- (id)valueForUndefinedKey:(NSString *)key
{
	id result = [super valueForUndefinedKey:key];
	if ([result isKindOfClass:[KTExtensiblePluginPropertiesArchivedObject class]])
	{
		result = nil;
	}
	return result;
}

/*	These 2 methods allow us to store and retrieve managed object even though they dont't conform to <NSCoding>
 *	Instead though they must conform to the KTArchivableManagedObject protocol
 */
- (NSDictionary *)unarchiveExtensibleProperties:(NSData *)propertiesData
{
	NSDictionary *result = [super unarchiveExtensibleProperties:propertiesData];
	
	// Go through all dictionary entries and swap any KTArchivedManagedObjects for the real thing
	NSEnumerator *keysEnumerator= [[NSDictionary dictionaryWithDictionary:result] keyEnumerator];
	NSString *aKey;
	while (aKey = [keysEnumerator nextObject])
	{
		id anObject = [result objectForKey:aKey];
		if ([anObject isKindOfClass:[KTExtensiblePluginPropertiesArchivedObject class]])
		{
			KTExtensiblePluginPropertiesArchivedObject *archivedObject = (KTExtensiblePluginPropertiesArchivedObject *)anObject;
			
            KTAbstractPage *page = nil;
            if ([self respondsToSelector:@selector(page)])
            {
                page = [self performSelector:@selector(page)];
            }
            else if ([self isKindOfClass:[KTAbstractPage class]])
            {
                page = (KTAbstractPage *)self;
            }
            
            KTDocument *document = [[page site] document];
            NSManagedObject *realObject = [archivedObject realObjectInDocument:document];
            [result setValue:realObject forKey:aKey];
		}
	}
	
	return result;
}

- (NSData *)archiveExtensibleProperties:(NSDictionary *)properties
{
	// Replace any managed objects conforming to KTArchivableManagedObject with KTArchivedManagedObject
	NSMutableDictionary *correctedProperties = [NSMutableDictionary dictionaryWithDictionary:properties];
	NSEnumerator *keysEnumerator = [properties keyEnumerator];
	NSString *aKey;
	
	while (aKey = [keysEnumerator nextObject])
	{
		id anObject = [properties objectForKey:aKey];
		if ([anObject isKindOfClass:[NSManagedObject class]] &&
			[anObject conformsToProtocol:@protocol(KTExtensiblePluginPropertiesArchiving)])
		{
			KTExtensiblePluginPropertiesArchivedObject *archivedObject =
			[[[KTExtensiblePluginPropertiesArchivedObject alloc] initWithObject:anObject] autorelease];
			
			[correctedProperties setValue:archivedObject forKey:aKey];
		}
	}
	
	NSData *result = [super archiveExtensibleProperties:correctedProperties];
	return result;
}


@end
