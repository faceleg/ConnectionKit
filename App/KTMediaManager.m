//
//  KTMediaManager2.m
//  Marvel
//
//  Created by Mike on 28/09/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTMediaManager+Internal.h"

#import "KT.h"
#import "KTDesign.h"
#import "KTDocument.h"
#import "KTDocumentInfo.h"
#import "KTExternalMediaFile.h"
#import "KTInDocumentMediaFile.h"
#import "KTMediaContainer.h"
#import "KTMediaManager.h"
#import "KTMediaPersistentStoreCoordinator.h"

#import "NSManagedObjectContext+KTExtensions.h"
#import "NSManagedObjectModel+KTExtensions.h"
#import "NSArray+Karelia.h"
#import "NSData+Karelia.h"
#import "NSString+Karelia.h"

#import "BDAlias.h"
#import <Connection/KTLog.h>

#import "Debug.h"


NSString *KTMediaLogDomain = @"Media";


@interface KTMediaManager ( Private )
// MediaContainer Creation
- (KTMediaContainer *)insertMediaContainer;
@end


#pragma mark -


@implementation KTMediaManager

#pragma mark -
#pragma mark Init & Dealloc

- (id)initWithDocument:(KTDocument *)document
{
	[super init];
	
	myDocument = document;	// Weak ref
	
	
	// Set up our MOC
	myMOC = [[NSManagedObjectContext alloc] init];
	[myMOC setUndoManager:nil];	// You can't auto-undo media stuff
	
	NSString *mediaModelPath = [[NSBundle mainBundle] pathForResource:@"Media" ofType:@"mom"];
	NSManagedObjectModel *mediaModel = [NSManagedObjectModel modelWithPath:mediaModelPath];
	
	KTMediaPersistentStoreCoordinator *mediaPSC =
		[[KTMediaPersistentStoreCoordinator alloc] initWithManagedObjectModel:mediaModel];
	[mediaPSC setMediaManager:self];
	[myMOC setPersistentStoreCoordinator:mediaPSC];
	[mediaPSC release];
	
	
	return self;
}

- (void)dealloc
{
	[myMOC release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (KTDocument *)document { return myDocument; }

/*	The Media Manager has its own prviate managed object context
 */
- (NSManagedObjectContext *)managedObjectContext { return myMOC; }

/*	Convenience method for accessing our MOC's associated MOM
 */
- (NSManagedObjectModel *)managedObjectModel
{
	NSManagedObjectModel *result = [[[self managedObjectContext] persistentStoreCoordinator] managedObjectModel];
	return result;
}

#pragma mark -
#pragma mark MediaContainer Creation

/*	Locates the KTMediaContainer object with the specified identifier. Returns nil if none is found.
 */
- (KTMediaContainer *)mediaContainerWithIdentifier:(NSString *)identifier
{
	KTMediaContainer *result = nil;
	
	if (identifier)
	{
		// Fetch first possible match
		NSFetchRequest *fetchRequest =
			[[self managedObjectModel] fetchRequestFromTemplateWithName:@"MediaWithIdentifier"
												   substitutionVariable:identifier forKey:@"IDENTIFIER"];
		
		[fetchRequest setFetchLimit:1];
		
		NSError *error = nil;
		NSArray *matches = [[self managedObjectContext] executeFetchRequest:fetchRequest error:&error];
		if (error) {
			[[NSAlert alertWithError:error] runModal];
		}
		
		result = [matches firstObjectOrNilIfEmpty];
	}
	
	return result;
}

- (KTMediaContainer *)mediaContainerWithPath:(NSString *)path
{
	OBPRECONDITION(path);
	
	KTMediaContainer *result = [self insertMediaContainer];
	[result setSourceAlias:[BDAlias aliasWithPath:path]];
	
	KTMediaFile *mediaFile = [self mediaFileWithPath:path];
	[result setValue:mediaFile forKey:@"file"];
	
	return result;
}

- (KTMediaContainer *)mediaContainerWithURL:(NSURL *)aURL
{
	KTMediaContainer *result = nil;
	
	if ( [aURL isFileURL] )
	{
		NSString *path = [aURL path];
		result = [self mediaContainerWithPath:path];
	}
	
	// TODO: in theory, we might be able to create a container
	// from the net using NSURLRequest/NSURLConnection or similar
	
	return result;
}

- (KTMediaContainer *)mediaContainerWithData:(NSData *)data filename:(NSString *)filename UTI:(NSString *)UTI;
{
	// Figure out a full filename
	NSString *fileExtension = [NSString filenameExtensionForUTI:UTI];
	NSAssert1(fileExtension && ![fileExtension isEqualToString:@""], @"UTI %@ has no corresponding file extension", UTI);
	OBASSERT(fileExtension);
	NSString *preferredFilename = [filename stringByAppendingPathExtension:fileExtension];
	
	// Create media container & file
	KTMediaContainer *result = [self insertMediaContainer];
	
	KTMediaFile *mediaFile = [self mediaFileWithData:data preferredFilename:preferredFilename];
	[result setValue:mediaFile forKey:@"file"];
	
	return result;
}

- (KTMediaContainer *)mediaContainerWithImage:(NSImage *)image;
{
	KTMediaContainer *result = [self insertMediaContainer];
	
	KTMediaFile *mediaFile = [self mediaFileWithImage:image];
	[result setValue:mediaFile forKey:@"file"];
	
	return result;
}

- (KTMediaContainer *)mediaContainerWithDraggingInfo:(id <NSDraggingInfo>)info preferExternalFile:(BOOL)external;
{
	KTMediaContainer *result = [self insertMediaContainer];
	
	KTMediaFile *mediaFile = [self mediaFileWithDraggingInfo:info preferExternalFile:external];
	[result setValue:mediaFile forKey:@"file"];
	
	// If the drag was a file, store the source alias
	if ([[[info draggingPasteboard] types] containsObject:NSFilenamesPboardType])
	{
		NSString *path = [[[info draggingPasteboard] propertyListForType:NSFilenamesPboardType] firstObjectOrNilIfEmpty];
		if (path)
		{
			[result setSourceAlias:[BDAlias aliasWithPath:path]];
		}
	}
	
	return result;
}

- (KTMediaContainer *)mediaContainerWithDataSourceDictionary:(NSDictionary *)dataSource;
{
	KTMediaContainer *result = nil;
	
	// File has highest priority
	if ([dataSource objectForKey:kKTDataSourceFilePath] )
	{
		NSString *path = [dataSource objectForKey:kKTDataSourceFilePath];
		result = [self mediaContainerWithPath:path];
	}
	// data has next highest priority
	else if ([dataSource objectForKey:kKTDataSourceData])
	{
		NSData *data = [dataSource objectForKey:kKTDataSourceData];
		NSString *fileName = [[dataSource objectForKey:kKTDataSourceFileName] stringByDeletingPathExtension];
		NSString *UTI = [dataSource objectForKey:kKTDataSourceUTI];
		result = [self mediaContainerWithData:data filename:fileName UTI:UTI];
	}
	// last priority, since it has no intrinsic image type
	else if ([dataSource objectForKey:kKTDataSourceImage])
	{
		NSImage *image = [dataSource objectForKey:kKTDataSourceImage];
		result = [self mediaContainerWithImage:image];
	}
	
	return result;
}

- (KTMediaContainer *)insertMediaContainer
{
	KTMediaContainer *result = [NSEntityDescription insertNewObjectForEntityForName:@"MediaContainer"
															 inManagedObjectContext:[self managedObjectContext]];
	
	return result;
}

#pragma mark -
#pragma mark Graphical Text

/*	Returns an existing graphical text MediaContainer or creates a new one.
 */
- (KTGraphicalTextMediaContainer *)graphicalTextWithString:(NSString *)string
													design:(KTDesign *)design
									  imageReplacementCode:(NSString *)imageReplacementCode
													  size:(float)size
{
	NSPredicate *predicate = [NSPredicate predicateWithFormat:
		@"text == %@ AND designIdentifier == %@ AND imageReplacementCode == %@ AND textSize BETWEEN { %f , %f }",
		string,
		[[design bundle] bundleIdentifier],
		imageReplacementCode,
		size - 0.01, size + 0.01];
	
	NSArray *objects = [[self managedObjectContext] objectsWithEntityName:@"GraphicalText" predicate:predicate error:NULL];
	KTGraphicalTextMediaContainer *result = [objects firstObjectOrNilIfEmpty];
	
	if (!result)
	{
		// Create the container
		result = [NSEntityDescription insertNewObjectForEntityForName:@"GraphicalText"
											   inManagedObjectContext:[self managedObjectContext]];
		
		[result setValue:string forKey:@"text"];
		[result setValue:[[design bundle] bundleIdentifier] forKey:@"designIdentifier"];
		[result setValue:imageReplacementCode forKey:@"imageReplacementCode"];
		[result setFloat:size forKey:@"textSize"];
		
		
		// Create the actual graphic
		NSImage *image = [design replacementImageForCode:imageReplacementCode
												  string:string
													size:[NSNumber numberWithFloat:size]];
		
		KTMediaFile *mediaFile = [self mediaFileWithImage:image];
		[result setValue:mediaFile forKey:@"file"];
	}
	
	return result;
}

#pragma mark -
#pragma mark Missing media

- (NSSet *)missingMediaFiles
{
	NSMutableSet *result = [NSMutableSet set];
	
	NSEnumerator *mediaFileEnumerator = [[self externalMediaFiles] objectEnumerator];
	KTExternalMediaFile *aMediaFile;
	
	while (aMediaFile = [mediaFileEnumerator nextObject])
	{
		NSString *path = [aMediaFile currentPath];
		if (!path || [path isEqualToString:@""] || ![[NSFileManager defaultManager] fileExistsAtPath:path])
		{
			[result addObject:aMediaFile];
		}
	}
	
	return result;
}

#pragma mark -
#pragma mark Errors

- (BOOL)fileManager:(NSFileManager *)manager shouldProceedAfterError:(NSDictionary *)errorInfo
{
	KTLog(KTMediaLogDomain, KTLogError, ([NSString stringWithFormat:@"Caught file manager error:\r%@", errorInfo]));
	return NO;
}

@end
