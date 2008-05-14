//
//  KTMediaManager+MediaContainers.m
//  Marvel
//
//  Created by Mike on 14/05/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTMediaManager.h"
#import "KTMediaManager+Internal.h"
#import "KTMediaContainer.h"

#import "KT.h"
#import "KTDesign.h"
#import "KTMediaFile.h"

#import "NSArray+Karelia.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSManagedObjectModel+KTExtensions.h"
#import "NSString+Karelia.h"

#import "BDAlias.h"


@interface KTMediaManager (MediaContainersPrivate)
- (KTMediaContainer *)insertNewMediaContainer;
@end


@implementation KTMediaManager (MediaContainers)

#pragma mark -
#pragma mark Existing Media Containers

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

#pragma mark -
#pragma mark New MediaContainers

- (KTMediaContainer *)mediaContainerWithPath:(NSString *)path
{
	OBPRECONDITION(path);
	
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

- (KTMediaContainer *)mediaContainerWithData:(NSData *)data filename:(NSString *)filename UTI:(NSString *)UTI;
{
	// Figure out a full filename
	NSString *fileExtension = [NSString filenameExtensionForUTI:UTI];
	NSAssert1(fileExtension && ![fileExtension isEqualToString:@""], @"UTI %@ has no corresponding file extension", UTI);
	OBASSERT(fileExtension);
	NSString *preferredFilename = [filename stringByAppendingPathExtension:fileExtension];
	
	// Create media container & file
	KTMediaContainer *result = [self insertNewMediaContainer];
	
	KTMediaFile *mediaFile = [self mediaFileWithData:data preferredFilename:preferredFilename];
	[result setValue:mediaFile forKey:@"file"];
	
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
#pragma mark Support

- (KTMediaContainer *)insertNewMediaContainer
{
	KTMediaContainer *result = [NSEntityDescription insertNewObjectForEntityForName:@"MediaContainer"
															 inManagedObjectContext:[self managedObjectContext]];
	
	return result;
}

@end
