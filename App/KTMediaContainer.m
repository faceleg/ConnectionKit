//
//  KTMedia2.m
//  Marvel
//
//  Created by Mike on 10/10/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "KTMediaContainer.h"

#import "KTGraphicalTextMediaContainer.h"

#import "KTMediaManager.h"

#import "KTImageScalingSettings.h"
#import "BDAlias.h"
#import "KTDocument.h"
#import "KTSite.h"

#import "NSString+Karelia.h"
#import "NSScanner+Karelia.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSSet+Karelia.h"


@implementation KTMediaContainer

#pragma mark -
#pragma mark Class Methods

+ (KTMediaContainer *)mediaContainerForURI:(NSURL *)mediaURI
{
	KTMediaContainer *result = nil;
	
	if ([[mediaURI scheme] isEqualToString:@"svxmedia"])
	{
		NSString *docID = [mediaURI host];
		NSString *mediaIdentifier = [self mediaContainerIdentifierForURI:mediaURI];
		
		
		// Search for suitable documents
		NSArray *openDocuments = [[NSDocumentController sharedDocumentController] documents];
		NSMutableArray *matchingDocs = [NSMutableArray array];
		
		NSEnumerator *docsEnumerator = [openDocuments objectEnumerator];
		KTDocument *aDoc;
		while (aDoc = [docsEnumerator nextObject])
		{
			if ([aDoc isKindOfClass:[KTDocument class]] && [[[aDoc site] siteID] isEqualToString:docID])
			{
				[matchingDocs addObject:aDoc];
			}
		}
		
		
		// In the event that no docs with that ID were found, fallback to searching all of them
		if ([matchingDocs count] == 0)
		{
			[matchingDocs setArray:openDocuments];
		}
		
		
		// Search each matching doc for the media
		docsEnumerator = [matchingDocs objectEnumerator];
		while (aDoc = [docsEnumerator nextObject])
		{
			if ([aDoc isKindOfClass:[KTDocument class]])
			{
				KTMediaManager *mediaManager = [aDoc mediaManager];
				result = [mediaManager mediaContainerWithIdentifier:mediaIdentifier];
				if (result) break;
			}
		}
	}
	
	return result;
}

+ (NSSet *)mediaContainerIdentifiersInHTML:(NSString *)HTML
{
    NSMutableSet *buffer = [[NSMutableSet alloc] init];
    if (HTML)
	{
		NSScanner *imageScanner = [[NSScanner alloc] initWithString:HTML];
		while (![imageScanner isAtEnd])
		{
			// Look for an image tag
			[imageScanner scanUpToString:@"<img" intoString:NULL];
			if ([imageScanner isAtEnd]) break;
			
			
			// Locate the image's source attribute
			[imageScanner scanUpToString:@"src=\"" intoString:NULL];
			[imageScanner scanString:@"src=\"" intoString:NULL];
			
			NSString *aMediaURIString = nil;
			if ([imageScanner scanUpToString:@"\"" intoString:&aMediaURIString])
			{
				NSURL *aMediaURI = [[NSURL alloc] initWithString:aMediaURIString];
				[buffer addObjectIgnoringNil:[self mediaContainerIdentifierForURI:aMediaURI]];
				[aMediaURI release];
			}
		}    
		
		[imageScanner release];
	}
    
    NSSet *result = [[buffer copy] autorelease];
    [buffer release];
    return result;
}

+ (NSString *)mediaContainerIdentifierForURI:(NSURL *)mediaURI
{
    NSString *result = nil;
    
    if ([[mediaURI scheme] isEqualToString:@"svxmedia"])
	{
        NSArray *pathComponents = [[mediaURI path] pathComponents];
        if ([pathComponents count] == 2)
        {
            result = [pathComponents objectAtIndex:1];
        }
    }
    
    return result;
}

#pragma mark -
#pragma mark Core Data

- (void)awakeFromInsert
{
	[super awakeFromInsert];
	
	[self setPrimitiveValue:[NSString UUIDString] forKey:@"identifier"];
}

- (void)awakeFromFetch
{
	[super awakeFromFetch];
	
	// Unarchive our alias
	if (![self isKindOfClass:[KTGraphicalTextMediaContainer class]])
	{
		NSData *aliasData = [self wrappedValueForKey:@"sourceAliasData"];
		if (aliasData)
		{
			[self setPrimitiveValue:[BDAlias aliasWithData:aliasData] forKey:@"sourceAlias"];
		}
	}
}

- (void)willSave
{
    // We must store the alias's data back into the store
	[self setPrimitiveValue:[[self sourceAlias] aliasData] forKey:@"sourceAliasData"];
    
	[super willSave];
}

+ (id)objectWithArchivedIdentifier:(NSString *)identifier inDocument:(KTDocument *)document
{
	id result = [[document mediaManager] mediaContainerWithIdentifier:identifier];
	return result;
}

- (NSString *)archiveIdentifier { return [self identifier]; }

#pragma mark -
#pragma mark Accessors

- (KTMediaManager *)mediaManager
{
	KTMediaManager *result = [[[self managedObjectContext] persistentStoreCoordinator] mediaManager];
	OBPOSTCONDITION(result);
	return result;
}

- (NSString *)identifier { return [self wrappedValueForKey:@"identifier"]; }

/*	Ensure that once it has been set the identifier cannot be changed.
 */
- (void)setIdentifier:(NSString *)identifier
{
	if ([self identifier])
	{
		[NSException raise:NSInvalidArgumentException
					format:@"-[KTMediaContainer identifier] is immutable"];
	}
	else
	{
		[self setWrappedValue:identifier forKey:@"identifier"];
	}
}

/*	A URI representation of the receiver than can be used to refer to the receiver later. Of the form:
 *
 *		svxmedia://document-id/media-identifer
 */
- (NSURL *)URIRepresentation
{
	KTDocument *document = [[self mediaManager] document];
	
	NSString *URLString = [NSString stringWithFormat:@"svxmedia://%@/%@",	
													 [[document site] siteID],
													 [self identifier]];
	
	NSURL *result = [NSURL URLWithString:URLString];
	return result;
}

- (BDAlias *)sourceAlias
{
	return [self wrappedValueForKey:@"sourceAlias"];
}

- (void)setSourceAlias:(BDAlias *)alias
{
	[self setWrappedValue:alias forKey:@"sourceAlias"];
}

- (KTMediaFile *)file { return [self wrappedValueForKey:@"file"]; }

@end
