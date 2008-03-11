//
//  KTAbstractMediaFile.m
//  Marvel
//
//  Created by Mike on 05/11/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTAbstractMediaFile.h"
#import "KTExternalMediaFile.h"

#import "Debug.h"
#import "KTMediaManager.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSObject+Karelia.h"

#import "BDAlias.h"
#import <QTKit/QTKit.h>


@interface KTAbstractMediaFile ()
- (KTMediaFileUpload *)insertUploadToPath:(NSString *)path;
- (NSString *)uniqueUploadPath:(NSString *)preferredPath;
@end


#pragma mark -


@implementation KTAbstractMediaFile

+ (void)initialize
{
	[self setKeys:[NSArray arrayWithObjects:@"filename", @"storageType", nil]
		triggerChangeNotificationsForDependentKey:@"currentPath"];
}

#pragma mark -
#pragma mark Core Data

+ (NSString *)entityName { return @"AbstractMediaFile"; }

#pragma mark -
#pragma mark Accessors

- (KTMediaManager *)mediaManager { return [[[self managedObjectContext] document] mediaManager]; }

- (NSString *)fileType { return [self primitiveValueForKey:@"fileType"]; }

- (void)setFileType:(NSString *)UTI
{
	[self setPrimitiveValue:UTI forKey:@"fileType"];
}

#pragma mark -
#pragma mark Paths

/*	The path where the underlying filesystem object is being kept.
 */
- (NSString *)currentPath
{
	OBASSERT_NOT_REACHED("A KTAbstractMediaFile subclass is not overriding -currentPath as it should");
	
	return nil;
}

/*	Subclasses implement this to return a <!svxData> pseudo-tag for Quick Look previews
 */
- (NSString *)quickLookPseudoTag
{
	[self subclassResponsibility:_cmd];
	return nil;
}

#pragma mark -
#pragma mark Uploading

- (KTMediaFileUpload *)defaultUpload
{
	// Create a MediaFileUpload object if needed
	KTMediaFileUpload *result = [[self valueForKey:@"uploads"] anyObject];
	
	if (!result)
	{
		// Find a unique path to upload to
		NSString *mediaDirectoryPath = [[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultMediaPath"];
		
		NSString *sourceFilename = nil;
		if ([self isKindOfClass:[KTInDocumentMediaFile class]]) {
			sourceFilename = [self valueForKey:@"sourceFilename"];
		}
		else {
			sourceFilename = [[[(KTExternalMediaFile *)self alias] fullPath] lastPathComponent];
		}
		
		NSString *preferredUploadPath = [mediaDirectoryPath stringByAppendingPathComponent:sourceFilename];
		NSString *uploadPath = [self uniqueUploadPath:preferredUploadPath];
		result = [self insertUploadToPath:uploadPath];
	}
	
	return result;
}

/*	If there isn't already an upload object for this path, create it.
 */
- (KTMediaFileUpload *)uploadForPath:(NSString *)path
{
	KTMediaFileUpload *result = nil;
	
	// Search for an existing upload
	NSSet *uploads = [self valueForKey:@"uploads"];
	NSEnumerator *uploadsEnumerator = [uploads objectEnumerator];
	KTMediaFileUpload *anUpload;
	
	while (anUpload = [uploadsEnumerator nextObject])
	{
		if ([[anUpload valueForKey:@"pathRelativeToSite"] isEqualToString:path])
		{
			result = anUpload;
			break;
		}
	}
	
	
	// If none was found, create a new upload
	if (!result)
	{
		result = [self insertUploadToPath:path];
	}
	
	
	return result;
}

/*	General, private method for creating a new media file upload.
 */
- (KTMediaFileUpload *)insertUploadToPath:(NSString *)path
{
	KTMediaFileUpload *result = [NSEntityDescription insertNewObjectForEntityForName:@"MediaFileUpload"
															  inManagedObjectContext:[self managedObjectContext]];
	
	[result setValue:path forKey:@"pathRelativeToSite"];
	[result setValue:self forKey:@"file"];
	
	return result;
}

- (NSString *)uniqueUploadPath:(NSString *)preferredPath
{
	NSString *result = preferredPath;
	
	NSString *basePath = [preferredPath stringByDeletingPathExtension];
	NSString *extension = [preferredPath pathExtension];
	unsigned count = 1;
	
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:[NSEntityDescription entityForName:@"MediaFileUpload" inManagedObjectContext:moc]];
	[fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"pathRelativeToSite like[c] %@", preferredPath]];
	[fetchRequest setFetchLimit:1];
	
	// Loop through, only ending when the file doesn't exist
	while ([[moc executeFetchRequest:fetchRequest error:NULL] count] > 0)
	{
		count++;
		NSString *aPath = [NSString stringWithFormat:@"%@-%u", basePath, count];
		result = [aPath stringByAppendingPathExtension:extension];
		[fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"pathRelativeToSite == %@", result]];
	}
	
	// Tidy up
	[fetchRequest release];
	return result;
}

#pragma mark -
#pragma mark Other

+ (float)scaleFactorOfSize:(NSSize)sourceSize toFitSize:(NSSize)desiredSize
{
	// Figure the approrpriate scaling factor
	float scale1 = desiredSize.width / sourceSize.width;
	float scale2 = desiredSize.height / sourceSize.height;
	
	float scaleFactor;
	if (scale2 < scale1) {
		scaleFactor = scale2; 
	} else {
		scaleFactor = scale1;
	}
	
	return scaleFactor;
}

+ (NSSize)sizeOfSize:(NSSize)sourceSize toFitSize:(NSSize)desiredSize
{
	// Scale the source image down, being sure to round the figures
	float scaleFactor = [self scaleFactorOfSize:sourceSize toFitSize:desiredSize];
	
	float width = roundf(scaleFactor * sourceSize.width);
	float height = roundf(scaleFactor * sourceSize.height);
	NSSize result = NSMakeSize(width, height);
	
	return result;
}

- (NSSize)dimensions
{
	NSSize result = NSZeroSize;
	
	NSNumber *width = [self wrappedValueForKey:@"width"];
	NSNumber *height = [self wrappedValueForKey:@"height"];
	
	if (width && height)
	{
		result = NSMakeSize([width floatValue], [height floatValue]);
	}
	
	return result;
}

- (float)imageScaleFactorToFitSize:(NSSize)desiredSize;
{
	return [KTInDocumentMediaFile scaleFactorOfSize:[self dimensions] toFitSize:desiredSize];
}

- (NSSize)imageSizeToFitSize:(NSSize)desiredSize
{
	NSSize result = [KTInDocumentMediaFile sizeOfSize:[self dimensions] toFitSize:desiredSize];
	return result;
}

/*	Similar to imageScaleFactorToFitSize: but ONLY takes into account the width
 */
- (float)imageScaleFactorToFitWidth:(float)width
{
	NSSize sourceSize = [self dimensions];
	float result = width / sourceSize.width;
	return result;
}

- (float)imageScaleFactorToFitHeight:(float)height;
{
	NSSize sourceSize = [self dimensions];
	float result = height / sourceSize.height;
	return result;
}

/*	Used by the Missing Media sheet. Assumes that the underlying filesystem object no longer exists so attempts
 *	to retrieve a 128x128 pixel version from the scaled images.
 */
- (NSString *)bestExistingThumbnail
{
	// Get the list of our scaled images by scale factor
	NSSortDescriptor *sortDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"scaleFactor" ascending:YES] autorelease];
	NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
	NSArray *scaledImages = [[[self valueForKey:@"scaledImages"] allObjects] sortedArrayUsingDescriptors:sortDescriptors];
	
	if ([scaledImages count] == 0) {
		return nil;
	}
	
	// What scale factor would we like?
	float scaleFactor = [self imageScaleFactorToFitSize:NSMakeSize(128.0, 128.0)];
	
	// Run through the list of scaled images. Bail if a good one is found
	NSEnumerator *scaledImagesEnumerator = [scaledImages objectEnumerator];
	KTAbstractMediaFile *bestMatch;
	while (bestMatch = [scaledImagesEnumerator nextObject])
	{
		if ([bestMatch floatForKey:@"scaleFactor"] >= scaleFactor) {
			break;
		}
	}
	if (!bestMatch)
	{
		bestMatch = [scaledImages lastObject];
	}
	
	// Create an NSImage from the scaled image
	NSString *result = [bestMatch currentPath];
	return result;
}

@end
