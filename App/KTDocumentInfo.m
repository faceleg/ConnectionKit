//
//  KTDocumentInfo.m
//  KTComponents
//
//  Created by Terrence Talbot on 5/21/05.
//  Copyright 2005 Karelia Software. All rights reserved.
//

#import "KTDocumentInfo.h"

#import "KT.h"
#import "KTDocument.h"
#import "KTManagedObjectContext.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSString+Karelia.h"

@implementation KTDocumentInfo

#pragma mark -
#pragma mark Init

- (void)awakeFromInsert
{
	[super awakeFromInsert];
	
	
	// Give ourself a unique ID
	NSString *siteID = [NSString shortGUIDString];
    [self setValue:siteID forKey:@"siteID"];
	
	
	// Create Host Properties object as well.
	NSManagedObject *hostProperties = [NSEntityDescription insertNewObjectForEntityForName:@"HostProperties"
																	inManagedObjectContext:[self managedObjectContext]];
	[self setValue:hostProperties forKey:@"hostProperties"];
}

#pragma mark -
#pragma mark Accessors

- (KTCopyMediaType)copyMediaOriginals { return [self wrappedIntegerForKey:@"copyMediaOriginals"]; }

- (void)setCopyMediaOriginals:(KTCopyMediaType)copy
{
	[self setWrappedInteger:copy forKey:@"copyMediaOriginals"];
	[[[self managedObjectContext] document] setUpdateMediaStorageAtNextSave:YES];
}

- (NSSet *)requiredBundlesIdentifiers
{
	return [self transientValueForKey:@"requiredBundlesIdentifiers" persistentArchivedDataKey:@"requiredBundlesData"];
}

- (void)setRequiredBundlesIdentifiers:(NSSet *)identifiers
{
	[self setTransientValue:identifiers forKey:@"requiredBundlesIdentifiers" persistentArchivedDataKey:@"requiredBundlesData"];
}

- (NSDictionary *)metadata
{
	return [self transientValueForKey:@"metadata" persistentPropertyListKey:@"metadataData"];
}

- (void)setMetadata:(NSDictionary *)metadata
{
	[self setTransientValue:metadata forKey:@"metadata" persistentPropertyListKey:@"metadataData"];
}

#pragma mark -
#pragma mark Quick Look

- (NSString *)pageCount
{
	NSArray *pages = [[self managedObjectContext] allObjectsWithEntityName:@"Page" error:NULL];
	NSString *result = [NSString stringWithFormat:@"%u", [pages count]];
	return result;
}

@end
