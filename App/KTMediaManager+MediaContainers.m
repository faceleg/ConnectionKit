//
//  KTMediaManager+MediaContainers.m
//  Marvel
//
//  Created by Mike on 14/05/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTMediaManager.h"
#import "KTMediaManager+Internal.h"
#import "KTMediaContainer.h"

#import "KT.h"
#import "KTDesign.h"
#import "KTDocument.h"
#import "KTMediaFile.h"

#import "NSArray+Karelia.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSManagedObjectModel+KTExtensions.h"
#import "NSString+Karelia.h"

#import "BDAlias.h"


@interface KTMediaManager (MediaContainersPrivate)
- (KTMediaContainer *)fetchMediaContainerWithIdentifier:(NSString *)identifier;
- (KTMediaContainer *)insertNewMediaContainer;
@end


#pragma mark -


@implementation KTMediaManager (MediaContainers)

#pragma mark -
#pragma mark Existing Media Containers

/*	Locates the KTMediaContainer object with the specified identifier. Returns nil if none is found.
 */
- (KTMediaContainer *)mediaContainerWithIdentifier:(NSString *)identifier
{
	OBPRECONDITION(identifier);
    
    
    // Load in the cache if needed
    if (!myMediaContainerIdentifiersCache)
    {
        NSArray *mediaContainers = [[self managedObjectContext] fetchAllObjectsForEntityForName:@"MediaContainer"
                                                                                   error:NULL];
        
        NSArray *mediaContainerIdentifiers = [mediaContainers valueForKey:@"identifier"];
        myMediaContainerIdentifiersCache = [[NSMutableDictionary alloc] initWithObjects:mediaContainers
                                                                                forKeys:mediaContainerIdentifiers];
    }
    
    
    // Search the cache for the identifier
    KTMediaContainer *result = [myMediaContainerIdentifiersCache objectForKey:identifier];
    
    
    // If the cache does not contain the object, fall back to fetching it, and cache the result
	if (!result)
    {
        result = [self fetchMediaContainerWithIdentifier:identifier];
        if (result) [myMediaContainerIdentifiersCache setObject:result forKey:identifier];
    }
	
	
	return result;
}

- (KTMediaContainer *)fetchMediaContainerWithIdentifier:(NSString *)identifier
{
	OBPRECONDITION(identifier);
    	
	// Fetch first possible match
    NSFetchRequest *fetchRequest =
    [[[self class] managedObjectModel] fetchRequestFromTemplateWithName:@"MediaWithIdentifier"
                                                   substitutionVariable:identifier forKey:@"IDENTIFIER"];
    [fetchRequest setFetchLimit:1];
    
    NSError *error = nil;
    NSArray *matches = [[self managedObjectContext] executeFetchRequest:fetchRequest error:&error];
    if (!matches) {
        [[self document] presentError:error];
    }
    
    return [matches firstObjectKS];
}

#pragma mark -
#pragma mark New MediaContainers

- (KTMediaContainer *)mediaContainerWithPath:(NSString *)path
{
	if(!path)
    {
        [NSException raise:NSInvalidArgumentException format:@"attempt to use nil path"];
    }
    
	
	KTMediaContainer *result = [self insertNewMediaContainer];
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

- (KTMediaContainer *)mediaContainerWithData:(NSData *)data filename:(NSString *)fileName fileExtension:(NSString *)extension
{
	OBPRECONDITION(data);
    OBPRECONDITION(fileName);   OBPRECONDITION(![fileName isEqualToString:@""]);
    OBPRECONDITION(extension);  OBPRECONDITION(![extension isEqualToString:@""]);
    
    
    // Figure out a full filename
	NSString *preferredFilename = [fileName stringByAppendingPathExtension:extension];
	
	// Create media container & file
	KTMediaContainer *result = [self insertNewMediaContainer];
	
	KTMediaFile *mediaFile = [self mediaFileWithData:data preferredFilename:preferredFilename];
	[result setValue:mediaFile forKey:@"file"];
	
	return result;
}


- (KTMediaContainer *)mediaContainerWithData:(NSData *)data filename:(NSString *)filename UTI:(NSString *)UTI;
{
	OBPRECONDITION(data);
    OBPRECONDITION(filename);
    OBPRECONDITION(UTI);
    
    
    KTMediaContainer *result = nil;
    
    // Figure out a full filename
	NSString *fileExtension = [NSString filenameExtensionForUTI:UTI];
	if (fileExtension)
    {
        result = [self mediaContainerWithData:data filename:filename fileExtension:fileExtension];
    }
    
    
    return result;
}

- (KTMediaContainer *)mediaContainerWithImage:(NSImage *)image;
{
	KTMediaContainer *result = [self insertNewMediaContainer];
	
	KTMediaFile *mediaFile = [self mediaFileWithImage:image];
	[result setValue:mediaFile forKey:@"file"];
	
	return result;
}

- (KTMediaContainer *)mediaContainerWithDraggingInfo:(id <NSDraggingInfo>)info preferExternalFile:(BOOL)external;
{
	KTMediaContainer *result = [self insertNewMediaContainer];
	
	KTMediaFile *mediaFile = [self mediaFileWithDraggingInfo:info preferExternalFile:external];
	[result setValue:mediaFile forKey:@"file"];
	
	// If the drag was a file, store the source alias
	if ([[[info draggingPasteboard] types] containsObject:NSFilenamesPboardType])
	{
		NSString *path = [[[info draggingPasteboard] propertyListForType:NSFilenamesPboardType] firstObjectKS];
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

#pragma mark -
#pragma mark Support

- (KTMediaContainer *)insertNewMediaContainer
{
	KTMediaContainer *result = [NSEntityDescription insertNewObjectForEntityForName:@"MediaContainer"
															 inManagedObjectContext:[self managedObjectContext]];
	
	return result;
}

/*  Generating media files is disabled when:
 *      A) Saving
 *      B) Closing the doc
 *      C) There is no media manager
 */
- (BOOL)scaledImageContainersShouldGenerateMediaFiles;
{
    
    //KTDocument *document = [self document];
    //BOOL result = ![document isSaving] && ![document isClosing];
    return YES;
}

@end
