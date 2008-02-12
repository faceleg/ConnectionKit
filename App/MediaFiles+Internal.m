//
//  KTAbstractMediaFile+MediaManagerPrivate.m
//  Marvel
//
//  Created by Mike on 07/11/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "MediaFiles+Internal.h"

#import "KTMediaManager+Internal.h"
#import "KTImageScalingSettings.h"

#import "BDAlias.h"



#pragma mark -


@implementation KTAbstractMediaFile (Internal)

+ (id)insertMediaFileWithPath:(NSString *)path inManagedObjectContext:(NSManagedObjectContext *)moc;
{
	id result = [NSEntityDescription insertNewObjectForEntityForName:[self entityName]
											  inManagedObjectContext:moc];
	
	[result setValue:[NSString GUIDString] forKey:@"uniqueID"];
	[result setFileType:[NSString UTIForFileAtPath:path]];
	
	
	// If the file is an image, also store the dimensions.
	if ([NSString UTI:[result fileType] conformsToUTI:(NSString *)kUTTypeImage])
	{
		CIImage *image = [[CIImage alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path]];
		CGSize imageSize = [image extent].size;
		[result setInteger:imageSize.width forKey:@"width"];
		[result setInteger:imageSize.height forKey:@"height"];
		[image release];
	}
	
	
	return result;
}

- (NSString *)preferredFileName
{
	NSString *result = nil;
	
	if ([self isKindOfClass:[KTInDocumentMediaFile class]])
	{
		result = [[[self valueForKey:@"sourceFilename"] lastPathComponent] stringByDeletingPathExtension];
	}
	else if ([self isKindOfClass:[KTExternalMediaFile class]])
	{
		result = [[[self valueForKeyPath:@"alias.lastKnownPath"] lastPathComponent] stringByDeletingPathExtension];
	}
	
	return result;
}

@end


#pragma mark -


@implementation KTExternalMediaFile (MediaManager)

+ (KTExternalMediaFile *)insertExternalMediaFileWithPath:(NSString *)path
						  inManagedObjectContext:(NSManagedObjectContext *)moc
{
	id result = [self insertMediaFileWithPath:path inManagedObjectContext:moc];
	
	[result setAlias:[BDAlias aliasWithPath:path]];
	
	return result;
}

@end


#pragma mark -


@implementation KTInDocumentMediaFile (MediaManager)

+ (id)insertMediaFileWithPath:(NSString *)path inManagedObjectContext:(NSManagedObjectContext *)moc
{
	id result = [super insertMediaFileWithPath:path inManagedObjectContext:moc];
	
	[result setValue:[path lastPathComponent] forKey:@"filename"];
	[result setValue:[NSData partiallyDigestStringFromContentsOfFile:path] forKey:@"digest"];
	
	return result;
}

/* The file on disk is NOT copied into the temp dir. We assume it is already there.
 */
+ (KTInDocumentMediaFile *)insertTemporaryMediaFileWithPath:(NSString *)path
						   inManagedObjectContext:(NSManagedObjectContext *)moc
{
	id result = [self insertMediaFileWithPath:path inManagedObjectContext:moc];
	return result;
}

@end
