//
//  KTMediaFile.m
//  Marvel
//
//  Created by Mike on 05/11/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "KTMediaFile.h"

#import "KTDocument.h"
#import "KTImageScalingSettings.h"
#import "KTImageScalingURLProtocol.h"
#import "KTMediaManager.h"
#import "KTMediaFileUpload.h"
#import "KTSite.h"

#import "NSManagedObject+KTExtensions.h"

#import "NSData+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"

#import "BDAlias+QuickLook.h"

#import <Connection/KTLog.h>
#import <QTKit/QTKit.h>

#import "Debug.h"



@interface KTMediaFile ()  

- (NSURL *)fileURLFromAlias;
- (NSURL *)savedFileURL;
- (NSURL *)deletedFileURL;

@property(nonatomic, copy) NSData *cachedDigest;

- (KTMediaFileUpload *)insertUploadToPath:(NSString *)path;
- (NSString *)uniqueUploadPath:(NSString *)preferredPath;
- (KTMediaFileUpload *)_anyUploadMatchingPredicate:(NSPredicate *)predicate;

@end


#pragma mark -


@implementation KTMediaFile

#pragma mark Init

+ (void)initialize
{
	[self setKeys:[NSArray arrayWithObjects:@"filename", @"storageType", nil]
		triggerChangeNotificationsForDependentKey:@"currentPath"];
}

+ (id)insertNewMediaFileWithPath:(NSString *)path inManagedObjectContext:(NSManagedObjectContext *)moc;
{
	return [NSEntityDescription insertNewObjectForEntityForName:[self entityName]
                                         inManagedObjectContext:moc];
}

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    [self setPrimitiveValue:[NSString UUIDString] forKey:@"uniqueID"];
}

#pragma mark Core Data

+ (NSString *)entityName { return @"MediaFile"; }

#pragma mark Accessors

- (KTMediaManager *)mediaManager
{
	KTMediaManager *result = [[[[self managedObjectContext] site] document] mediaManager];
	OBPOSTCONDITION(result);
	return result;
}

#pragma mark Location

- (NSURL *)fileURL;
{
	if ([self filename])
    {
        // Figure out proper values for these two
        if ([self isInserted])
        {
            return [self deletedFileURL];
        }
        else
        {
            return [self savedFileURL];
        }
    }
    else
    {
        return [self fileURLFromAlias];
    }
}

- (NSURL *)fileURLFromAlias;
{
    // Get best path we can out of the alias
    NSString *path = [[self alias] fullPath];
	if (!path) path = [[self alias] lastKnownPath];
    
    // Ignore files which are in the Trash
	if ([path rangeOfString:@".Trash"].location != NSNotFound) path = nil;
    
    
    if (path) return [NSURL fileURLWithPath:path];
    return nil;
}

- (NSURL *)savedFileURL;
{
    NSURL *storeURL = [[[self objectID] persistentStore] URL];
    NSURL *docURL = [KTDocument documentURLForDatastoreURL:storeURL];
    
    NSURL *result = [docURL URLByAppendingPathComponent:[self filename]
                                            isDirectory:NO];
    return result;
}

- (NSURL *)deletedFileURL;
{
    NSURL *result = [NSURL fileURLWithPath:[[[self mediaManager] temporaryMediaPath] stringByAppendingPathComponent:[self filename]]];
    return result;
}

/*	The path where the underlying filesystem object is being kept.
 */
- (NSString *)currentPath
{
	NSString *result = [[self fileURL] path];
    if (!result)
    {
        result = [[NSBundle mainBundle] pathForImageResource:@"qmark"];
    }
    
	return result;
}

#pragma mark Location Support

@dynamic filename;

- (BDAlias *)alias
{
	BDAlias *result = [self wrappedValueForKey:@"alias"];
	
	if (!result)
	{
		NSData *aliasData = [self valueForKey:@"aliasData"];
		if (aliasData)
		{
			result = [BDAlias aliasWithData:aliasData];
			[self setPrimitiveValue:result forKey:@"alias"];
		}
	}
	
	return result;
}

- (void)setAlias:(BDAlias *)alias
{
	[self setWrappedValue:alias forKey:@"alias"];
	[self setValue:[alias aliasData] forKey:@"aliasData"];
}

@dynamic preferredFilename;
- (BOOL)validatePreferredFilename:(NSString **)filename error:(NSError **)outError
{
    //  Make sure it really is just a filename and not a path
    BOOL result = [[*filename pathComponents] count] == 1;
    if (!result && outError)
    {
        NSDictionary *info = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"perferredFilename \"%@\" is a path; not a filename", *filename]
                                                         forKey:NSLocalizedDescriptionKey];
        *outError = [NSError errorWithDomain:NSCocoaErrorDomain
                                        code:NSValidationStringPatternMatchingError
                                    userInfo:info];
    }
    
    return result;
}

#pragma mark File Management

/*	Called when a MediaFile is saved for the first time. i.e. it becomes peristent and the underlying file needs to move into the doc.
 */
- (void)moveIntoDocument
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	KTDocument *doc = [[self mediaManager] document];
	if (!doc) return;	// Safety check for handling store migration
	
	
	// Simple debug log of what's about to go down		(see, I'm streetwise. No, really!)
	NSString *filename = [self filename];
	KTLog(KTMediaLogDomain,
		  KTLogDebug,
		  ([NSString stringWithFormat:@"Moving temporary MediaFile %@ into the document", filename]));
	
	
	// Only bother if there is actually a file to move
	NSString *sourcePath = [[[self mediaManager] temporaryMediaPath] stringByAppendingPathComponent:filename];
	if (![fileManager fileExistsAtPath:sourcePath])
	{
		KTLog(KTMediaLogDomain,
			  KTLogInfo,
			  ([NSString stringWithFormat:@"No file to move at:\n%@", [sourcePath stringByAbbreviatingWithTildeInPath]]));
        
		return;
	}
	
	
	// Make sure the destination is available
	NSString *destinationPath = [[self savedFileURL] path];
	if ([fileManager fileExistsAtPath:destinationPath])
	{
		KTLog(KTMediaLogDomain,
			  KTLogWarn,
			  ([NSString stringWithFormat:@"%@\nalready exists; overwriting it.", [destinationPath stringByAbbreviatingWithTildeInPath]]));
		
		[fileManager removeFileAtPath:destinationPath handler:self];
	}
	
    
	// Make the move
	if (![fileManager movePath:sourcePath toPath:destinationPath handler:self])
	{
		KTLog(KTMediaLogDomain,
			  KTLogError,
			  @"-[%@ %@] failed moving from %@ to %@",
			  NSStringFromClass([self class]),
			  NSStringFromSelector(_cmd),
			  [sourcePath stringByAbbreviatingWithTildeInPath],
			  [destinationPath stringByAbbreviatingWithTildeInPath]);
	}
}

- (void)didSave
{
    [super didSave];
    
    
	// Both -insertedObjects and KTLog seems to be pretty memory intensive during data migration, so give them a local pool
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	
	// If we have just been saved then move our underlying file into the document
	if ([self isInserted])
	{
		// During Save As operations, the files on disk are handled for us, so don't do this
        //if ([[[self managedObjectContext] persistentStoreCoordinator] isKindOfClass:[KTMediaPersistentStoreCoordinator class]])
        {
            [self moveIntoDocument];
        }
	}
	
	
	// If we have been deleted from the context, move our underlying file back out to the temp dir
	if ([self isDeleted])
	{
		NSString *filename = [self committedValueForKey:@"filename"];
		NSString *sourcePath = [[[self mediaManager] mediaPath] stringByAppendingPathComponent:filename];
		NSString *destinationPath = [[[self mediaManager] temporaryMediaPath] stringByAppendingPathComponent:filename];
		
		KTLog(KTMediaLogDomain, KTLogDebug,
			  ([NSString stringWithFormat:@"The in-document MediaFile %@ has been deleted. Moving it to the temp media directory", filename]));
		
		if ([[NSFileManager defaultManager] fileExistsAtPath:sourcePath])
		{
			[[self mediaManager] prepareTemporaryMediaDirectoryForFileNamed:filename];
			if (![[NSFileManager defaultManager] movePath:sourcePath toPath:destinationPath handler:self]) {
				[NSException raise:NSInternalInconsistencyException
							format:@"Unable to move deleted MediaFile %@ to the temp media directory", filename];
			}
		}
		else
		{
			NSString *message = [NSString stringWithFormat:@"No file could be found at\n%@\nDeleting the MediaFile object it anyway",
                                 [sourcePath stringByAbbreviatingWithTildeInPath]];
			KTLog(KTMediaLogDomain, KTLogWarn, message);
		}
	}
	
	
	[pool release];
}

#pragma mark Digest

#define DIGESTDATALENGTH 8192

+ (NSData *)mediaFileDigestFromData:(NSData *)data
{
    unsigned int length = [data length];
	unsigned int lengthToDigest = MIN(length, (unsigned int)DIGESTDATALENGTH);
	NSData *firstPart = [data subdataWithRange:NSMakeRange(0,lengthToDigest)];
	NSData *result = [firstPart SHA1HashDigest];
	return result;
}

+ (NSData *)mediaFileDigestFromContentsOfFile:(NSString *)path
{
    NSData *result = nil;
	id fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
	if (fileHandle)
	{
		NSData *data = [fileHandle readDataOfLength:DIGESTDATALENGTH];
		result = [data SHA1HashDigest];
		
		[fileHandle closeFile];
	}
	return result;
}

@dynamic cachedDigest;

#pragma mark Quick Look

/*	Subclasses implement this to return a <!svxData> pseudo-tag for Quick Look previews
 */
- (NSString *)quickLookPseudoTag
{
    if ([self filename])
    {
        NSString *result = [NSString stringWithFormat:@"<!svxdata indocumentmedia:%@>",
                            [self filename]];
        return result;
    }
    else
    {
        NSString *result = [[self alias] quickLookPseudoTag];
        return result;
    }
}

#pragma mark Uploading

- (KTMediaFileUpload *)defaultUpload
{
	// Create a MediaFileUpload object if needed
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"scalingProperties == nil"];
	KTMediaFileUpload *result = [self _anyUploadMatchingPredicate:predicate];
	
	if (!result || [result isDeleted])
	{
		// Find a unique path to upload to
		NSString *sourceFilename = [self preferredFilename];
		
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
    
    
    // Canonical scaling props
    if (scalingProps) scalingProps = [self canonicalImageScalingPropertiesForProperties:scalingProps];
    
    
	KTImageScalingSettings *scalingSettings = [scalingProps objectForKey:@"scalingBehavior"];
	NSString *fileType = [scalingProps objectForKey:@"fileType"];
    
    if (scalingProps &&
            !([scalingSettings behavior] == KTScaleByFactor &&
              [scalingSettings scaleFactor] == 1.0))
	{
        NSString *path = [[self fileURL] path];
        if (!path || ![[[NSWorkspace sharedWorkspace] typeOfFile:path error:NULL] isEqualToUTI:fileType])
        {
            // Load the scaled image
            NSString *path = [self currentPath];
            if (path)
            {
                if (fileType)
                {
                    // Look for an existing upload
                    NSPredicate *predicate = [NSPredicate predicateWithFormat:
                                              @"scalingProperties == %@ AND pathRelativeToSite != %@",
                                              scalingProps,
                                              [[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultMediaPath"]];
                    
                    result = [self _anyUploadMatchingPredicate:predicate];
                    
                    
                    // If not, create our own
                    if (!result)
                    {
                        NSString *sourceFilename = [self preferredFilename];
                        
                        // Case 40782. A nil sourceFilename gives a path of "_Media" wreaking havoc when publishing
                        if (sourceFilename || [sourceFilename isEqualToString:@""]) 
                        { 
                            NSString *preferredFileName = [[sourceFilename stringByDeletingPathExtension] legalizedWebPublishingFileName];
                            NSString *preferredFilename = [preferredFileName stringByAppendingPathExtension:[NSString filenameExtensionForUTI:fileType]];
                            
                            NSString *mediaDirectoryPath = [[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultMediaPath"];
                            NSString *preferredUploadPath = [mediaDirectoryPath stringByAppendingPathComponent:preferredFilename];
                            
                            NSString *uploadPath = [self uniqueUploadPath:preferredUploadPath];
                            result = [self insertUploadToPath:uploadPath];
                            [result setScalingProperties:scalingProps];
                        }
                    }
                }
            }
        }
        else
        {
            result = [self defaultUpload];
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

/*	Used by the Missing Media sheet. Assumes that the underlying filesystem object no longer exists so attempts
 *	to retrieve a 128x128 pixel version from the scaled images.
 */
- (NSString *)bestExistingThumbnail
{
	return nil;     // Cheating for the moment and assuming no thumbnails
}

#pragma mark Scaling

- (NSURL *)URLForImageScaledToSize:(NSSize)size mode:(KSImageScalingMode)scalingMode sharpening:(float)sharpening fileType:(NSString *)UTI
{
	NSURL *baseURL = [[NSURL alloc] initWithScheme:KTImageScalingURLProtocolScheme
											  host:[[[[self mediaManager] document] site] siteID]
											  path:[@"/" stringByAppendingPathComponent:[self valueForKey:@"uniqueID"]]];
	
	NSMutableDictionary *query = [[NSMutableDictionary alloc] init];
	
    if (!NSEqualSizes(size, NSZeroSize)) [query setObject:NSStringFromSize(size) forKey:@"size"];
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
	// Grab canonical version if possible
	if (properties)
	{
		properties = [self canonicalImageScalingPropertiesForProperties:properties];
	}
	
	
	// Is any scaling actually required?
	KTImageScalingSettings *settings = [properties objectForKey:@"scalingBehavior"];
	if (!properties || ([settings behavior] == KTScaleByFactor &&
                        [settings scaleFactor] == 1.0 &&
                        [[properties objectForKey:@"fileType"] isEqualToString:[self fileType]]))
	{
		properties = nil;
	}
		
	
	// Generate a scaled URL only if requested
	if (properties)
	{
		KSImageScalingMode mode = KSImageScalingModeAspectFit; // use most common value to avoid warning
		switch ([settings behavior])
		{
			case KTScaleToSize:
				mode = KSImageScalingModeAspectFit;
				break;
			case KTStretchToSize:
				mode = KSImageScalingModeFill;
				break;
			case KTCropToSize:
				mode = [settings alignment] + 11;  // +11 converts from KTMediaScalingOperation to KSImageScalingMode
				break;
			default:
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

- (NSURLRequest *)URLRequestForImageScalingProperties:(NSDictionary *)properties
{
    NSMutableURLRequest *result = [NSMutableURLRequest requestWithURL:[self URLForImageScalingProperties:properties]];
    
    NSString *path = [self currentPath];
    if (path)
    {
        [result setScaledImageSourceURL:[NSURL fileURLWithPath:path]];
    }
    
    return result;
}

/*	Takes some properties and makes them suitable for the media system to search and generate images with.
 *  Returns scaleFactor = 1.0 if the settings will result in no change to the image.
 */ 
- (NSDictionary *)canonicalImageScalingPropertiesForProperties:(NSDictionary *)properties
{
	OBPRECONDITION(properties);
    
    
    NSMutableDictionary *buffer = [properties mutableCopy];
	
	/*
	// Figure the canonical scaling specification
	KTImageScalingSettings *specifiedScalingSettings = [properties objectForKey:@"scalingBehavior"];
    OBASSERT(specifiedScalingSettings);
    KTImageScalingSettings *canonicalScalingSettings = [self canonicalImageScalingSettingsForSettings:specifiedScalingSettings];
    [buffer setObject:canonicalScalingSettings forKey:@"scalingBehavior"];
    
    
    // Unless the requested scaling will result in no change, figure out what to apply for the other settings
    if ([canonicalScalingSettings behavior] == KTScaleByFactor && [canonicalScalingSettings scaleFactor] == 1.0)
    {
        // For GIF images, when no scaling is required, we logically want to maintain the file format
        if ([[self fileType] conformsToUTI:(NSString *)kUTTypeGIF])
        {
            [buffer setObject:(NSString *)kUTTypeGIF forKey:@"fileType"];
        }
    }
    else
    {
        // Ensure there is a compression setting
        NSNumber *compression = [properties objectForKey:@"compression"];
        if (KSISNULL(compression))
        {
            compression = [[NSUserDefaults standardUserDefaults] objectForKey:@"KTPreferredJPEGQuality"];
            [buffer setObject:compression forKey:@"compression"];
        }
        
        
        // Ensure there is a sharpening factor
        NSNumber *sharpening = [properties objectForKey:@"sharpeningFactor"];
        if (KSISNULL(sharpening))
        {
            sharpening = [NSNumber numberWithFloat:
                          [[NSUserDefaults standardUserDefaults] floatForKey:@"KTSharpeningFactor"]];
            [buffer setObject:sharpening forKey:@"sharpeningFactor"];
        }
    }
    
    
    
    // If there is still no set file type, we can oftentimes know it by looking at if the image has an alpha component
    if (![buffer objectForKey:@"fileType"])
    {
        BOOL preferPNGFormat = [[NSUserDefaults standardUserDefaults] boolForKey:@"KTPrefersPNGFormat"];
        NSNumber *hasAlphaComponent = [self hasAlphaComponent];
        
        if (preferPNGFormat || (hasAlphaComponent && [hasAlphaComponent boolValue]))
        {
            [buffer setObject:(NSString *)kUTTypePNG forKey:@"fileType"];
        }
        else if (hasAlphaComponent) // Therefore [hasAlphaComponent boolValue]==NO and prefers JPEG
        {
            [buffer setObject:(NSString *)kUTTypeJPEG forKey:@"fileType"];
        }
        else
        {
            [self cacheHasAlphaComponentIfNeeded];
            hasAlphaComponent = [self hasAlphaComponent];
            if (hasAlphaComponent)
            {
                if ([hasAlphaComponent boolValue])
                {
                    [buffer setObject:(NSString *)kUTTypePNG forKey:@"fileType"];
                }
                else
                {
                    [buffer setObject:(NSString *)kUTTypeJPEG forKey:@"fileType"];
                }
            }
        }
    }
    
    
                    
    // Double-check there are compression and sharpening settings
    NSNumber *compression = [buffer objectForKey:@"compression"];
    if (KSISNULL(compression))
    {
        [buffer setObject:[NSNumber numberWithInt:0] forKey:@"compression"];
    }
    NSNumber *sharpening = [buffer objectForKey:@"sharpeningFactor"];
    if (KSISNULL(sharpening))
    {
        [buffer setObject:[NSNumber numberWithInt:0] forKey:@"sharpeningFactor"];
    }
	
	*/
    
	// Tidy up
	NSDictionary *result = [[buffer copy] autorelease];
    [buffer release];
    OBPOSTCONDITION(result);
	return result;
}

/*  Support method to handle the scaling aspect of the previous method.
 */
- (KTImageScalingSettings *)canonicalImageScalingSettingsForSettings:(KTImageScalingSettings *)settings
{
    OBPRECONDITION(settings);
    
    
    /*
    
    // CropToSize operations are already pretty much sorted
    KTMediaScalingOperation behavior = [settings behavior];
    if (behavior == KTCropToSize)
    {
        [self cacheImageDimensionsIfNeeded];
        NSSize size = [self dimensions];
        if (size.width <= [settings size].width && size.height <= [settings size].height)
        {
            settings = [KTImageScalingSettings settingsWithScaleFactor:1.0];
        }
        
        return settings;
    }
    
    
    // Scale by a factor of 1.0 is already sorted
    if (behavior == KTScaleByFactor && [settings scaleFactor] == 1.0)
    {
        return settings;
    }
    
    
    // Convert wishy washy behaviours (scaleByFactor, scaleToSize) to a definite stretch operation
    if (behavior != KTStretchToSize)
    {
        // But first make sure that we have valid image dimension informatiom
        [self cacheImageDimensionsIfNeeded];
		
        
        
        NSSize suggestedSize = [settings scaledSizeForImageOfSize:[self dimensions]];   // Clang, we assert settings is non-nil above
        NSSize roundedSize = NSMakeSize(roundf(suggestedSize.width), roundf(suggestedSize.height));
        
        settings = [KTImageScalingSettings settingsWithBehavior:KTStretchToSize size:roundedSize];
    }
	
    
    // We should now have a simple stretchToFit operation.
    // Double-check that it is not equivalent to a scale by 1.0 operation
    OBASSERT([settings behavior] == KTStretchToSize);
    if (NSEqualSizes([settings size], [self dimensions]))
    {
        settings = [KTImageScalingSettings settingsWithScaleFactor:1.0];
    }
    */
	
    OBPOSTCONDITION(settings);
	return settings;
}

@end
