//
//  KTMediaFile.m
//  Marvel
//
//  Created by Mike on 05/11/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTMediaFile+Internal.h"
#import "KTInDocumentMediaFile.h"
#import "KTExternalMediaFile.h"

#import "KTDocumentInfo.h"
#import "KTImageScalingSettings.h"
#import "KTImageScalingURLProtocol.h"
#import "KTMediaManager.h"
#import "KTMediaPersistentStoreCoordinator.h"
#import "KTMediaFileUpload.h"

#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"

#import "NSObject+Karelia.h"
#import "NSSortDescriptor+Karelia.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"

#import "BDAlias.h"
#import <QTKit/QTKit.h>

#import "Debug.h"



@interface KTMediaFile (Private)  
- (KTMediaFileUpload *)insertUploadToPath:(NSString *)path;
- (NSString *)uniqueUploadPath:(NSString *)preferredPath;
- (KTMediaFileUpload *)_anyUploadMatchingPredicate:(NSPredicate *)predicate;
@end


#pragma mark -


@implementation KTMediaFile

#pragma mark -
#pragma mark Init

+ (void)initialize
{
	[self setKeys:[NSArray arrayWithObjects:@"filename", @"storageType", nil]
		triggerChangeNotificationsForDependentKey:@"currentPath"];
}

+ (id)insertNewMediaFileWithPath:(NSString *)path inManagedObjectContext:(NSManagedObjectContext *)moc;
{
	id result = [NSEntityDescription insertNewObjectForEntityForName:[self entityName]
											  inManagedObjectContext:moc];
	
	[result setValue:[NSString UUIDString] forKey:@"uniqueID"];
	[result setFileType:[NSString UTIForFileAtPath:path]];
	
	
	// If the file is an image, also store the dimensions when possible
	if ([NSString UTI:[result fileType] conformsToUTI:(NSString *)kUTTypeImage])
	{
		[result cacheImageDimensions];
	}
	
	
	return result;
}

#pragma mark -
#pragma mark Core Data

+ (NSString *)entityName { return @"AbstractMediaFile"; }

#pragma mark -
#pragma mark Accessors

- (KTMediaManager *)mediaManager
{
	KTMediaManager *result = [(KTMediaPersistentStoreCoordinator *)[[self managedObjectContext] persistentStoreCoordinator] mediaManager];
	OBPOSTCONDITION(result);
	return result;
}

- (NSString *)fileType { return [self primitiveValueForKey:@"fileType"]; }

- (void)setFileType:(NSString *)UTI
{
	[self setPrimitiveValue:UTI forKey:@"fileType"];
}

- (NSString *)filename
{
    SUBCLASSMUSTIMPLEMENT;
    return nil;
}

- (NSString *)filenameExtension
{
    SUBCLASSMUSTIMPLEMENT;
    return nil;
}

#pragma mark -
#pragma mark Paths

/*	The path where the underlying filesystem object is being kept.
 */
- (NSString *)currentPath
{
	NSString *result = [self _currentPath];
    if (!result)
    {
        result = [[NSBundle mainBundle] pathForImageResource:@"qmark"];
    }
    
	return result;
}

- (NSString *)_currentPath
{
	SUBCLASSMUSTIMPLEMENT;
	return nil;
}

/*	Subclasses implement this to return a <!svxData> pseudo-tag for Quick Look previews
 */
- (NSString *)quickLookPseudoTag
{
	SUBCLASSMUSTIMPLEMENT;
	return nil;
}

- (NSString *)preferredFileName
{
	SUBCLASSMUSTIMPLEMENT;
	return nil;
}

#pragma mark -
#pragma mark Uploading

- (KTMediaFileUpload *)defaultUpload
{
	// Create a MediaFileUpload object if needed
	KTMediaFileUpload *result = [[self valueForKey:@"uploads"] anyObject];
	
	if (!result || [result isDeleted])
	{
		// Find a unique path to upload to
		NSString *sourceFilename = nil;
		if ([self isKindOfClass:[KTInDocumentMediaFile class]])
        {
			sourceFilename = [self valueForKey:@"sourceFilename"];
		}
		else
        {
			sourceFilename = [[[(KTExternalMediaFile *)self alias] fullPath] lastPathComponent];
		}
		
		NSString *preferredFileName = [[sourceFilename stringByDeletingPathExtension] legalizedWebPublishingFileName];
        NSString *pathExtension = [[sourceFilename pathExtension] lowercaseString];
		NSString *preferredFilename = [preferredFileName stringByAppendingPathExtension:pathExtension];
        
        NSString *mediaDirectoryPath = [[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultMediaPath"];
		NSString *preferredUploadPath = [mediaDirectoryPath stringByAppendingPathComponent:preferredFilename];
		
        NSString *uploadPath = [self uniqueUploadPath:preferredUploadPath];
		result = [self insertUploadToPath:uploadPath];
	}
    
    
    OBASSERT(result);
    
    
    // Make sure the result is a valid upload. If not, correct the path, or delete the upload and try again.
    // This is because prior to 1.5b4, we could sometimes mistakenly create an invalid path object.
    NSString *path = [result pathRelativeToSite];
    
    NSString *validatedPath = path;
    if (![result validateValue:(id *)&validatedPath forKey:@"pathRelativeToSite" error:NULL])
    {
        [[result managedObjectContext] deleteObject:result];        
        result = [self defaultUpload];
    }
    else if (path != validatedPath)
    {
        [result setValue:validatedPath forKey:@"pathRelativeToSite"];
    }
	
	return result;
}

/*	If there isn't already an upload object for this path, create it.
 */
- (KTMediaFileUpload *)uploadForPath:(NSString *)path
{
	OBPRECONDITION(path);
    
    
	// Search for an existing upload
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathRelativeToSite == %@", path];
	KTMediaFileUpload *result = [self _anyUploadMatchingPredicate:predicate];
	
	
	// If none was found, create a new upload
	if (!result)
	{
		result = [self insertUploadToPath:path];
	}
	
	
	return result;
}

- (KTMediaFileUpload *)uploadForScalingProperties:(NSDictionary *)scalingProps
{
	KTMediaFileUpload *result = nil;
	
	if (scalingProps)
	{
		// Load the scaled image
		NSString *path = [self currentPath];
		if (path)
		{
			NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:[self URLForImageScalingProperties:scalingProps]];
			[URLRequest setScaledImageSourceURL:[NSURL fileURLWithPath:path]];
			
			NSURLResponse *URLResponse = nil;
			NSData *imageData = [NSURLConnection sendSynchronousRequest:URLRequest returningResponse:&URLResponse error:NULL];
			if (imageData && URLResponse)
			{
				NSString *fileType = [NSString UTIForMIMEType:[URLResponse MIMEType]];
				
				
				// Look for an existing upload
				NSMutableDictionary *fullScalingProps = [scalingProps mutableCopy];
				[fullScalingProps setObject:fileType forKey:@"fileType"];
				[fullScalingProps setFloat:[[NSUserDefaults standardUserDefaults] floatForKey:@"KTPreferredJPEGQuality"] forKey:@"compression"];
				if (![scalingProps objectForKey:@"sharpeningFactor"]) [fullScalingProps setFloat:[[NSUserDefaults standardUserDefaults] floatForKey:@"KTSharpeningFactor"] forKey:@"sharpeningFactor"];
				
				
				NSPredicate *predicate = [NSPredicate predicateWithFormat:@"scalingProperties == %@", fullScalingProps];
				
				result = [self _anyUploadMatchingPredicate:predicate];
				
				
				// If not, create our own
				if (!result)
				{
					NSString *sourceFilename = nil;
					if ([self isKindOfClass:[KTInDocumentMediaFile class]])
					{
						sourceFilename = [self valueForKey:@"sourceFilename"];
					}
					else
					{
						sourceFilename = [[[(KTExternalMediaFile *)self alias] fullPath] lastPathComponent];
					}
					
					NSString *preferredFileName = [[sourceFilename stringByDeletingPathExtension] legalizedWebPublishingFileName];
					NSString *preferredFilename = [preferredFileName stringByAppendingPathExtension:[NSString filenameExtensionForUTI:fileType]];
					
					NSString *mediaDirectoryPath = [[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultMediaPath"];
					NSString *preferredUploadPath = [mediaDirectoryPath stringByAppendingPathComponent:preferredFilename];
					
					NSString *uploadPath = [self uniqueUploadPath:preferredUploadPath];
					result = [self insertUploadToPath:uploadPath];
					[result setScalingProperties:fullScalingProps];
				}
				
				[fullScalingProps release];
			}
		}
	}
	else
	{
		result = [self defaultUpload];
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
	
    NSString *parentDirectory = [preferredPath stringByDeletingLastPathComponent];
	NSString *baseFileName = [[preferredPath lastPathComponent] stringByDeletingPathExtension];
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
        NSString *countString = [NSString stringWithFormat:@"-%u", count];
		
        unsigned maxFileNameLength = 27 - [countString length]; // Some servers can't handle long filenames
        NSString *truncatedFileName = [baseFileName stringByTrimmingToLength:maxFileNameLength];
        NSString *aPath = [parentDirectory stringByAppendingPathComponent:[truncatedFileName stringByAppendingString:countString]];
		
        OBASSERT(extension);
		result = [aPath stringByAppendingPathExtension:extension];
		
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"pathRelativeToSite == %@", result]];
	}
	
	// Tidy up
	[fetchRequest release];
	return result;
}

- (KTMediaFileUpload *)_anyUploadMatchingPredicate:(NSPredicate *)predicate
{
	OBPRECONDITION(predicate);
    
    
	// Search for an existing upload
	NSSet *uploads = [self valueForKey:@"uploads"];
	NSEnumerator *uploadsEnumerator = [uploads objectEnumerator];
	KTMediaFileUpload *result;
	
	while (result = [uploadsEnumerator nextObject])
	{
		if ([predicate evaluateWithObject:result])
		{
			break;
		}
	}
	
	return result;
}

#pragma mark -
#pragma mark Pasteboard

- (id <NSCoding>)pasteboardRepresentation
{
	SUBCLASSMUSTIMPLEMENT;
    return nil;
}

- (id <NSCoding>)IDOnlyPasteboardRepresentation
{
	return [self pasteboardRepresentation];
}

#pragma mark -
#pragma mark Images

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

/*  Attempts to read image dimensions in from disk and store them.
 */
- (void)cacheImageDimensions
{
    NSNumber *imageWidth = nil;
    NSNumber *imageHeight = nil;
    
    NSString *imagePath = [self _currentPath];
    if (imagePath)
    {
        NSURL *imageURL = [NSURL fileURLWithPath:imagePath];
        OBASSERT(imageURL);
        
        CIImage *image = [[CIImage alloc] initWithContentsOfURL:imageURL];
        if (image)
        {
            CGSize imageSize = [image extent].size;
            imageWidth = [NSNumber numberWithFloat:imageSize.width];
            imageHeight = [NSNumber numberWithFloat:imageSize.height];
            [image release];
        }
        else
        {
            // BUGSID:31429. Fallback to NSImage which can sometimes handle awkward PICT images etc.
            NSImage *image = [[NSImage alloc] initWithContentsOfURL:imageURL];
            if (image)
            {
                NSSize imageSize = [image size];
                imageWidth = [NSNumber numberWithFloat:imageSize.width];
                imageHeight = [NSNumber numberWithFloat:imageSize.height];
                [image release];
            }
        }
    }
    
    [self setValue:imageWidth forKey:@"width"];
    [self setValue:imageHeight forKey:@"height"];
}

- (void)cacheImageDimensionsIfNeeded
{
    NSNumber *width = [self valueForKey:@"width"];
    NSNumber *height = [self valueForKey:@"height"];
    
    if (!width ||
        !height ||
        ![self validateValue:(id *)&width forKey:@"width" error:NULL]
		||
        ![self validateValue:(id *)&height forKey:@"height" error:NULL]
		)
    {
        [self cacheImageDimensions];
    }
}

/*	Used by the Missing Media sheet. Assumes that the underlying filesystem object no longer exists so attempts
 *	to retrieve a 128x128 pixel version from the scaled images.
 */
- (NSString *)bestExistingThumbnail
{
	return nil;     // Cheating for the moment and assuming no thumbnails
}

#pragma mark -
#pragma mark Scaling

- (NSURL *)URLForImageScaledToSize:(NSSize)size mode:(KSImageScalingMode)scalingMode sharpening:(float)sharpening fileType:(NSString *)UTI
{
	NSURL *baseURL = [[NSURL alloc] initWithScheme:KTImageScalingURLProtocolScheme
											  host:[[[[self mediaManager] document] documentInfo] siteID]
											  path:[@"/" stringByAppendingPathComponent:[self valueForKey:@"uniqueID"]]];
	
	NSMutableDictionary *query = [[NSMutableDictionary alloc] init];
	[query setObject:NSStringFromSize(size) forKey:@"size"];
	[query setObject:[NSString stringWithFormat:@"%i", scalingMode] forKey:@"mode"];
	if (UTI) [query setObject:UTI forKey:@"filetype"];
	[query setFloat:[[NSUserDefaults standardUserDefaults] floatForKey:@"KTPreferredJPEGQuality"] forKey:@"compression"];
	
	if (!sharpening) sharpening = [[NSUserDefaults standardUserDefaults] floatForKey:@"KTSharpeningFactor"];
	[query setObject:[NSString stringWithFormat:@"%f", sharpening] forKey:@"sharpen"];
	
	
	NSURL *result = [NSURL URLWithBaseURL:baseURL parameters:query];
	[query release];
	[baseURL release];
	
	return result;
}

/*	Generates one of the special x-sandvox-image URLs we use for previewing scaled images.
 *	Returns a file URL if properties is nil
 */
- (NSURL *)URLForImageScalingProperties:(NSDictionary *)properties
{
	if (properties)
	{
		KTImageScalingSettings *settings = [properties objectForKey:@"scalingBehavior"];
		
		KSImageScalingMode mode;
		switch ([settings behavior])
		{
			case KTScaleToSize:
				mode = KSImageScalingModeAspectFit;
				break;
			case KTStretchToSize:
				mode = KSImageScalingModeFill;
				break;
			case KTCropToSize:
				mode = [settings alignment] + 11;
				break;
			default:
				OBASSERT_NOT_REACHED("Unknown scaling behaviour");
				break;
		}
		
		NSURL *result = [self URLForImageScaledToSize:[settings size]
												 mode:mode
										   sharpening:[properties floatForKey:@"sharpeningFactor"]
											 fileType:[properties objectForKey:@"fileType"]];
		
		return result;
	}
	else
	{
		NSURL *result = nil;
		NSString *path = [self currentPath];
		if (path)
		{
			result = [NSURL fileURLWithPath:path];
		}
		
		return result;	
	}
}

@end
