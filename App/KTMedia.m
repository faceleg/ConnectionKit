//
//  KTMedia.m
//  KTComponents
//
//  Created by Terrence Talbot on 3/10/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTMedia.h"

#import "KTDesign.h"
#import "BDAlias.h"
#import "Debug.h"
#import "KT.h"
#import "KTCachedImage.h"
#import "KTDocument.h"
#import "KTManagedObject.h"
//#import "KTOldMediaManager.h"
#import "KTPage.h"
#import "NSDocumentController+KTExtensions.h"
#import "NSImage+Karelia.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSString+Karelia.h"
#import "NSString-Utilities.h"
#import "NSThread+Karelia.h"
#import "NSWorkspace+Karelia.h"
#import <QTKit/QTKit.h>
#import <QuartzCore/QuartzCore.h>

NSString *kKTMediaException = @"KTMediaException";


@interface NSWindowController ( KTDocWindowControllerHack )
- (KTPage *)selectedPage;
@end


@interface NSObject ( KTMediaURLProtocolHack )
+ (NSURL *)URLForDocument:(KTDocument *)aDocument 
				  mediaID:(NSString *)aMediaID
				imageName:(NSString *)anImageName;
@end

@interface QTMovie ( iMediaBrowserHack )
- (NSImage *)betterPosterImage;
@end

@interface KTMedia ( Private )
+ (KTMedia *)mediaWithData:(NSData *)someData
					  name:(NSString *)aName
	 uniformTypeIdentifier:(NSString *)aUTI
		insertIntoManagedObjectContext:(KTManagedObjectContext *)aContext
		   convertOriginal:(BOOL)aConvertFlag;

- (void)setCachedIcons:(NSMutableDictionary *)aDictionary;
- (NSImage *)inspectorImage;
- (void)setInspectorImage:(NSImage *)anImage;
- (void)setUniqueID:(NSString *)value;

- (BOOL)substituteOriginalForImageName:(NSString *)anImageName;
- (void)setSubstitutableImageNames:(NSMutableSet *)aSubstitutableImageNames;

- (KTCachedImage *)cachedImageForImageName:(NSString *)anImageName;
- (void)prepopulateCachedImages;

+ (void)displayMediaErrorAlertForWindow:(NSWindow *)window
						informativeText:(NSString *)informativeText;
- (void)setPosterImage:(NSImage *)aPosterImage;

- (void)removeObservers;
@end


@implementation KTMedia


// +initialize moved to KTMedia+ScaledImages.m

+ (KTMediaStorageType)defaultStorageType
{
	return KTMediaCopyContentsStorage;
}

#pragma mark public (convenience) constructors

// FIXME: using 32x32 tiff here, instead of .ico, at least until Apple fixes NSImage!
+ (KTMedia *)defaultFaviconForPage:(KTPage *)aPage
{
	USESDEPRECATEDAPI;
	// see if the context has a favicon.ico media object
	KTManagedObjectContext *context = (KTManagedObjectContext *)[aPage managedObjectContext];
	[context lockPSCAndSelf];
	
	KTMedia *result = [[aPage oldMediaManager] objectWithName:@"favicon" managedObjectContext:context];
	if ( nil == result )
	{
		// if not, we need to create it from data, since the filename won't be favicon
		NSString *faviconPath = [[NSBundle mainBundle] pathForImageResource:@"32favicon"];
		NSData *data = [NSData dataWithContentsOfFile:faviconPath];
		result = [KTMedia mediaWithData:data
								   name:@"favicon"
				  uniformTypeIdentifier:[NSString UTIForFileAtPath:faviconPath]
		 insertIntoManagedObjectContext:context
						convertOriginal:NO];
		//[[aPage document] saveContext:context onlyIfNecessary:YES];
	}
	
	[context unlockPSCAndSelf];
	return result;
}

/*!	Create media from file.  Automatically determine storage type
*/
+ (KTMedia *)mediaWithContentsOfFile:(NSString *)aPath
	  insertIntoManagedObjectContext:(KTManagedObjectContext *)aContext
{
	NSParameterAssert(nil != aContext);
	
	KTMedia *result = nil;
	
	// analyze aPath to see if we should use Alias storage
    //  anything in iPhoto (using defaults) becomes an alias
	BOOL isIPhoto = NO;
	NSDictionary *iPhotoDefaults = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.apple.iPhoto"];
	NSString *iPhotoRoot = [iPhotoDefaults valueForKey:@"RootDirectory"];	
	if ( nil != iPhotoRoot )
	{
		if ( [aPath hasPrefix:iPhotoRoot] )
		{
			isIPhoto = YES;
		}
	}
    
    //  anything in iTunes (using defaults) becomes an alias
    BOOL isITune = NO;
	
	if (!isIPhoto)	// don't bother checking if it's an iphoto
	{
		static NSString *sITunesRoot = nil;
		if (nil == sITunesRoot)
		{
//			// see if we can just grab it from the iTunes Music Library.xml file (is this guaranteed to exist?)
//			// I can find no documentation that suggests there is any better way to get the iTunes path than this
//			// iTunesRecentDatabases is another possibility, see, e.g., http://www.dougscripts.com/itunes/itinfo/locatemf.php
//			NSString *XMLPath = [@"~/Music/iTunes/iTunes Music Library.xml" stringByResolvingSymlinksInPath];
//			if ( (nil != XMLPath) && [[NSFileManager defaultManager] fileExistsAtPath:XMLPath] )
//			{
//// FIXME: iTunesInfo could be expensive to read in as a dictionary, would it be better to walk the XML? 
//				NSDictionary *iTunesInfo = [NSDictionary dictionaryWithContentsOfFile:XMLPath];
//				if ( nil != [iTunesInfo valueForKey:@"Music Folder"] )
//				{
//					NSURL *iTunesRootURL = [NSURL URLWithString:[iTunesInfo valueForKey:@"Music Folder"]];
//					if ( [iTunesRootURL isFileURL] )
//					{
//						BOOL isDir = NO;
//						if ( [[NSFileManager defaultManager] fileExistsAtPath:XMLPath isDirectory:&isDir] )
//						{
//							if ( isDir )
//							{
//								sITunesRoot = [[iTunesRootURL path] copy];
//							}
//						}
//					}
//				}
//			}
//			
//			// if we couldn't get it from the XML file, try defaults
//			if ( nil == sITunesRoot )
//			{
// FIXME: the defaults key used here was determined empirically and could break!
// FIXME: This could be very slow to resolve if this points who-knows-where.  And it doesn't save the alias back if it's changed. 
				NSDictionary *iTunesDefaults = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.apple.iTunes"];
				NSString *musicFolderLocationKey = @"alis:11345:Music Folder Location";
				NSData *aliasData = [iTunesDefaults valueForKey:musicFolderLocationKey];
				BDAlias *alias = [[[BDAlias alloc] initWithData:aliasData] autorelease];
				sITunesRoot = [[alias fullPath] retain];
//			}
		}
		if ( nil != sITunesRoot )
		{
			if ( [aPath hasPrefix:sITunesRoot] )
			{
				isITune = YES;
			}
		}
    }
    //  anything in ~/Movies, ~/Music, or ~/Pictures becomes an alias
    //  NB: there appear to be no standard library functions for finding these
	//  but supposedly these names are constant and .localized files
	//  change what name appears in Finder
	
	// We resolve symbolic links so that the path of the arbitrary file added will match the actual path
	// of the home directory
	
    BOOL isInHomeMediaDirectory = NO;
    NSString *homeDirectory = NSHomeDirectory();
    NSString *moviesDirectory	= [[homeDirectory stringByAppendingPathComponent:@"Movies"] stringByResolvingSymlinksInPath];
    NSString *musicDirectory	= [[homeDirectory stringByAppendingPathComponent:@"Music"] stringByResolvingSymlinksInPath];
    NSString *picturesDirectory	= [[homeDirectory stringByAppendingPathComponent:@"Pictures"] stringByResolvingSymlinksInPath];
    
    if ( [aPath hasPrefix:moviesDirectory] || [aPath hasPrefix:musicDirectory] || [aPath hasPrefix:picturesDirectory] )
    {
        isInHomeMediaDirectory = YES;
    }

	KTDocument *document = (KTDocument *)[[NSDocumentController sharedDocumentController] documentForManagedObjectContext:aContext];
	NSAssert((nil != document), @"document is nil!");
		
	KTCopyMediaType copyType = [[document root] integerForKey:@"copyMediaOriginalsInherited"];
	switch ( copyType )
	{
		case KTCopyMediaAll:
			// everything goes in
			result = [self mediaWithContentsOfFile:aPath 
									   storageType:[self defaultStorageType]
					insertIntoManagedObjectContext:aContext];
			break;
		case KTCopyMediaNone:
			// everything becomes aliases
			result = [self mediaWithContentsOfFile:aPath 
									   storageType:KTMediaCopyAliasStorage
					insertIntoManagedObjectContext:aContext];
			break;
		case KTCopyMediaAutomatic:
		default:
		{				
			if ( isIPhoto || isITune || isInHomeMediaDirectory )
			{
				result = [self mediaWithContentsOfFile:aPath 
										   storageType:KTMediaCopyAliasStorage
						insertIntoManagedObjectContext:aContext];
			}
			else
			{
				result = [self mediaWithContentsOfFile:aPath 
										   storageType:[self defaultStorageType]
						insertIntoManagedObjectContext:aContext];
			}
		}
			break;
	}
			
	return result;
}

+ (KTMedia *)mediaWithDataSourceDictionary:(NSDictionary *)aDataSourceDictionary
			insertIntoManagedObjectContext:(KTManagedObjectContext *)aContext
{
	KTMedia *result = nil;
	// File has highest priority since maybe we can make an alias
	if ( nil != [aDataSourceDictionary valueForKey:kKTDataSourceFilePath] )
	{
		result = [KTMedia mediaWithContentsOfFile:[aDataSourceDictionary valueForKey:kKTDataSourceFilePath]
				   insertIntoManagedObjectContext:aContext];
	}
	// data has next highest priority
	else if (nil != [aDataSourceDictionary objectForKey:kKTDataSourceData])
	{
		NSString *fileName = [[aDataSourceDictionary objectForKey:kKTDataSourceFileName] stringByDeletingPathExtension];
		result = [KTMedia mediaWithData:[aDataSourceDictionary objectForKey:kKTDataSourceData]
								   name:fileName
				  uniformTypeIdentifier:[aDataSourceDictionary objectForKey:kKTDataSourceUTI]
		 insertIntoManagedObjectContext:aContext];
	}
	// last priority, since it has no intrinsic image type
	else if (nil != [aDataSourceDictionary objectForKey:kKTDataSourceImage])
	{
		result = [KTMedia mediaWithImage:[aDataSourceDictionary objectForKey:kKTDataSourceImage]
		  insertIntoManagedObjectContext:aContext];
	}
    else if ( nil != [aDataSourceDictionary objectForKey:kKTDataSourceNil] )
    {
        result = nil;
    }
    
	return result;	
}

+ (KTMedia *)mediaWithImage:(NSImage *)anImage insertIntoManagedObjectContext:(KTManagedObjectContext *)aContext
{
	KTMedia *result = [self mediaWithImage:anImage
									  name:nil
					 uniformTypeIdentifier:(NSString *)kUTTypeTIFF // force conversion to preferredFormat
			insertIntoManagedObjectContext:aContext];
	return result;
}

#pragma mark full-blown constructors

+ (KTMedia *)mediaWithContentsOfFile:(NSString *)aPath
						 storageType:(KTMediaStorageType)aStorageType
	  insertIntoManagedObjectContext:(KTManagedObjectContext *)aContext
{	
	NSAssert((nil != aPath), @"aPath cannot be nil");
	NSAssert((nil != aContext), @"aContext cannot be nil");
		
	KTDocument *document = (KTDocument *)[[NSDocumentController sharedDocumentController] documentForManagedObjectContext:aContext];

	NSData *storableData = nil;
	NSString *storableUTI = nil;
	BOOL didConvertOriginal = NO;
	
	// is aPath readable?
	NSFileManager *fm = [NSFileManager defaultManager];
	BOOL isDirectory;
	BOOL fileExists  = [fm fileExistsAtPath:aPath isDirectory:&isDirectory] && !isDirectory;
	BOOL isReadable = [fm isReadableFileAtPath:aPath];
	if ( !fileExists || !isReadable )
	{
		NSLog(@"error: unable to read file at path %@", aPath);
		if ( nil != document )
		{
			NSString *localizedInformativeText = [NSString stringWithFormat:NSLocalizedString(@"Unable to read file at path %@. A placeholder may be substituted.","Alert Info"), aPath];
			[self displayMediaErrorAlertForWindow:[[document windowController] window]
								  informativeText:localizedInformativeText];
		}
		return nil;
	}
	
	// compute initial UTI
	NSString *fileUTI = [NSString UTIForFileAtPath:aPath];
	if ( nil != fileUTI )
	{
		storableUTI = fileUTI;
	}
	else
	{
		NSLog(@"error: unable to compute UTI at path %@.", aPath);
		if ( nil != document )
		{
			NSString *localizedInformativeText = [NSString stringWithFormat:NSLocalizedString(@"Unable to compute UTI at path %@. A placeholder may be substituted.","Alert Info"), aPath];
			[self displayMediaErrorAlertForWindow:[[document windowController] window]
								  informativeText:localizedInformativeText];
		}
		return nil;
	}
		
	if ( [NSString UTI:storableUTI conformsToUTI:@"public.image"] )
	{
		// we think it's an image, let's check magic number	
		BOOL appearsToBeImage = [NSImage containsImageDataAtPath:aPath];
		if (!appearsToBeImage)
		{
			// magic number check failed, let's see if NSImage can make sense of it
			NSImage *image = [[[NSImage alloc] initWithContentsOfFile:aPath] autorelease];
			appearsToBeImage = (nil != image);
		}
		
		if ( !appearsToBeImage )
		{
			NSLog(@"error: unable to create image from file at path %@", aPath);
			if ( nil != document )
			{
				NSString *localizedInformativeText = [NSString stringWithFormat:NSLocalizedString(@"Unable to create image from file at path %@. A placeholder may be substituted.","Alert Info"), aPath];
				[self displayMediaErrorAlertForWindow:[[document windowController] window]
									  informativeText:localizedInformativeText];
			}
			return nil;
		}
		else if ( [KTMedia shouldConvertOriginalWithUTI:storableUTI] )
		{
			// convert (image) data to preferred format
			// expensive, but in practice this should only affect TIFFs
			NSImage *image = [[[NSImage alloc] initWithContentsOfFile:aPath] autorelease];
			[image normalizeSize];
			storableData = [image preferredRepresentation];
			storableUTI = [image preferredFormatUTI];
			if ( (nil == storableData) || (nil == storableUTI) )
			{
				NSLog(@"error: unable to convert image at path %@ to preferred format.", aPath);
				if ( nil != document )
				{
					NSString *localizedInformativeText = [NSString stringWithFormat:NSLocalizedString(@"Unable to convert image at path %@ to preferred format. A placeholder may be substituted.","Alert Info"), aPath];
					[self displayMediaErrorAlertForWindow:[[document windowController] window]
										  informativeText:localizedInformativeText];
				}
				return nil;
			}
			else
			{
				didConvertOriginal = YES; // this is basically to handle TIFFs converted to preferredFormat
				aStorageType = KTMediaCopyContentsStorage;	// force us to NOT reference the original.
			}
		}
	}
	
	// calculate digest
	NSString *mediaDigest = nil;
	if ( didConvertOriginal )
	{
		mediaDigest = [storableData partiallyDigestString];
	}
	else
	{
		mediaDigest = [NSData partiallyDigestStringFromContentsOfFile:aPath];
	}

	// lock the context
	[aContext lockPSCAndSelf];

	// find or create media using digest
	KTMedia *media = nil;
	
	if ( [mediaDigest length] > 0 )
	{
		media = [aContext objectMatchingMediaDigest:mediaDigest thumbnailDigest:nil];
		if ( nil != media )
		{
			//TJT((@"+mediaWithContentsOfFile: will use pre-existing media %@", [media name]));
			[aContext unlockPSCAndSelf];
			return media;
		}
	}
	
	media = [NSEntityDescription insertNewObjectForEntityForName:@"Media" inManagedObjectContext:aContext];
	if ( nil != media )
	{
		// we need a unique name, before we do *anything* else, start with the path
		NSString *uniqueName = [[aPath lastPathComponent] stringByDeletingPathExtension];

		/// generate unique ID soon so we can use it for unique name if needed
		NSString *uniqueID = [[media document] nextUniqueID];
		[media setUniqueID:uniqueID];

		// remove any spaces or other bad guys in the name
		uniqueName = [uniqueName legalizeFileNameWithFallbackID:uniqueID];
		
		// make sure uniqueName is actually unique
		if ( nil != document )
		{
            NSAssert((nil != [document oldMediaManager]), @"neither document nor media manager should be nil");
			uniqueName = [[document oldMediaManager] uniqueNameWithName:uniqueName managedObjectContext:aContext];
		}
		NSAssert((nil != uniqueName), @"uniqueName should not be nil");
		
		// make sure we can store the data
		KTManagedObject *storage = [NSEntityDescription insertNewObjectForEntityForName:@"MediaData"
																 inManagedObjectContext:aContext];
		
		if ( nil == storage )
		{
			NSLog(@"error: unable to create MediaData object for media at %@.", aPath);
			[aContext deleteObject:media];
			[aContext unlockPSCAndSelf];
			return nil;
		}
		
		switch ( aStorageType )
		{
			case KTMediaCopyFileStorage:
			{
				NSLog(@"warning: KTMediaCopyFileStorage is unsupported in this release. Using KTMediaCopyContentsStorage instead.");
				// fall through to KTMediaCopyContentsStorage
			}
			case KTMediaCopyContentsStorage:
			{
				NSData *data = nil;
				if ( didConvertOriginal )
				{
					data = storableData;
				}
				else
				{
					data = [NSData dataWithContentsOfFile:aPath];
				}
				[storage setValue:data forKey:@"contents"];
                [media setValue:[NSNumber numberWithUnsignedInt:[data length]] forKey:@"mediaDataLength"];
				[media setMediaData:storage];
				[media setStorageType:KTMediaCopyContentsStorage];
				break;
			}
			case KTMediaCopyAliasStorage:
			{
				BDAlias *alias = [BDAlias aliasWithPath:aPath relativeToPath:[NSHomeDirectory()  stringByResolvingSymlinksInPath]];
				if (nil == alias)
				{
					// couldn't find relative to home directory, so just do absolute
					alias = [BDAlias aliasWithPath:aPath];
				}

				NSData *aliasData = [alias aliasData];
				[storage setValue:aliasData forKey:@"contents"];
                [media setValue:[NSNumber numberWithUnsignedInt:[aliasData length]] forKey:@"mediaDataLength"];
				[media setMediaData:storage];
				[media setStorageType:KTMediaCopyAliasStorage];
				break;
			}
			case KTMediaPlaceholderStorage:
			{
				NSData *data = [NSData dataWithContentsOfFile:aPath];
				
				[storage setValue:data forKey:@"contents"];		// store data as fallback image
                [media setValue:[NSNumber numberWithUnsignedInt:[data length]] forKey:@"mediaDataLength"];
				[media setMediaData:storage];
				[media setStorageType:KTMediaPlaceholderStorage];
				
				// Since this is a singleton, and we want to be notified on changes to design, register that here
				if ( [NSThread isMainThread] )
				{
					/// Case 18430: only add observers on main thread
					[[NSNotificationCenter defaultCenter] addObserver:media
															 selector:@selector(clearMediaCaches:)
																 name:kKTDesignChangedNotification
															   object:nil];
				}
				break;
			}
			default:
				NSLog(@"error: unable to create media, unknown storage type %i", aStorageType);
				[aContext deleteObject:media];
				[aContext deleteObject:storage];
				[aContext unlockPSCAndSelf];
				return nil;
		}
		
		// store digest as hash for uniqueing between contexts
		if ( [mediaDigest length] > 0 )
		{
			[media setValue:mediaDigest forKey:@"mediaDigest"];
			[media setValue:mediaDigest forKeyPath:@"mediaData.digest"];
		}    
		
		// store UTI
		if ( didConvertOriginal )
		{
			[media setMediaUTI:storableUTI];
		}
		else
		{
			[media setMediaUTI:fileUTI];
		}
		
		//TJT((@"+mediaWithContentsOfFile: creating new media %@ %@", uniqueName, uniqueID));
		
		[media setName:uniqueName];	
		
		if ( !didConvertOriginal )
		{
			NSDictionary *fattrs = [[NSFileManager defaultManager] fileAttributesAtPath:aPath traverseLink:YES];
			
			//[media setFileAttributesFromDictionary:fattrs];	/// Mike: Not in 1.5 model
			[media setOriginalPath:aPath];
			
			NSDate *creationDate = [fattrs objectForKey:NSFileCreationDate];
			NSCalendarDate *creationCalendarDate = [creationDate dateWithCalendarFormat:kKTDefaultCalendarFormat 
																			   timeZone:nil];
			[media setOriginalCreationDate:creationCalendarDate];						
		}
		else
		{
			NSCalendarDate *creationCalendarDate = [[NSCalendarDate date] dateWithCalendarFormat:kKTDefaultCalendarFormat 
																						timeZone:nil];
			[media setOriginalCreationDate:creationCalendarDate];						
		}
		
		// prepopulate CachedImages
		[media prepopulateCachedImages];

		// we inserted some new objects, we might need to save them
		//[[media document] saveContext:(KTManagedObjectContext *)[media managedObjectContext] onlyIfNecessary:YES];
    }
	else
	{
		NSLog(@"Unable to create new Media object.");
	}
	
	[aContext unlockPSCAndSelf];
		
    return media;
}

+ (KTMedia *)mediaWithData:(NSData *)someData
					  name:(NSString *)aName	// optional
	 uniformTypeIdentifier:(NSString *)aUTI
		insertIntoManagedObjectContext:(KTManagedObjectContext *)aContext
{
	KTMedia *media = [self mediaWithData:someData
									name:aName
				   uniformTypeIdentifier:aUTI
		  insertIntoManagedObjectContext:aContext
						 convertOriginal:YES];
	return media;
}

+ (KTMedia *)mediaNotFoundMediaWithDocument:(KTDocument *)aDocument
{
	KTMedia *media = nil;
	
	NSImage *image = [NSImage qmarkImage];
	[image normalizeSize];
	NSData *storableData = [image preferredRepresentation];
	NSString *storableUTI = [image preferredFormatUTI];
	NSString *mediaDigest = [storableData partiallyDigestString];
	
	KTManagedObjectContext *context = (KTManagedObjectContext *)[aDocument managedObjectContext];
	NSAssert((nil != context), @"context should not be nil");
	[context lockPSCAndSelf];
	
	media = [NSEntityDescription insertNewObjectForEntityForName:@"Media" inManagedObjectContext:context];
	if ( nil != media )
	{		
        [media setUniqueID:[aDocument nextUniqueID]];
		NSAssert((nil != [media valueForKey:@"uniqueID"]), @"media has nil uniqueID");
		[media setName:kKTMediaNotFoundMediaName];
		[media setStorageType:KTMediaCopyContentsStorage];
		
		// store the data
		KTManagedObject *storage = [NSEntityDescription insertNewObjectForEntityForName:@"MediaData"
																 inManagedObjectContext:context];
		if ( nil == storage )
		{
			NSLog(@"error: unable to create MediaData object.");
			[context deleteObject:media];
			[context unlockPSCAndSelf];
			return nil;
		}
		[storage setValue:storableData forKey:@"contents"];
        [media setValue:[NSNumber numberWithUnsignedInt:[storableData length]] forKey:@"mediaDataLength"];
		[media setMediaData:storage];
		[media setMediaUTI:storableUTI];
		
		// store digest as hash for uniqueing between contexts
		if ( [mediaDigest length] > 0 )
		{
			[media setValue:mediaDigest forKey:@"mediaDigest"];
			[media setValue:mediaDigest forKeyPath:@"mediaData.digest"];
		}    
		
		// set our creation date to now
		[media setOriginalCreationDate:[NSCalendarDate calendarDate]];
		
		// we're not going to save the context here, document creation will take care of that
	}
	
	[context unlockPSCAndSelf];
	return media;
}

+ (KTMedia *)mediaWithData:(NSData *)someData
					  name:(NSString *)aName	// optional
	 uniformTypeIdentifier:(NSString *)aUTI
		insertIntoManagedObjectContext:(KTManagedObjectContext *)aContext
		   convertOriginal:(BOOL)aConvertFlag
{
	NSAssert((nil != someData), @"someData is nil!");
	NSAssert((nil != aUTI), @"UTI is nil!");
	NSAssert((nil != aContext), @"aContext is nil!");
	
	KTDocument *document = (KTDocument *)[[NSDocumentController sharedDocumentController] documentForManagedObjectContext:aContext];

	NSData *storableData = someData;
	NSString *storableUTI = aUTI;
	
	// first convert (image) data to preferred format
	if ( aConvertFlag && [KTMedia shouldConvertOriginalWithUTI:aUTI] )
	{
		NSImage *image = [[[NSImage alloc] initWithData:someData] autorelease];
		if ( nil != image )
		{
			[image normalizeSize];
			storableData = [image preferredRepresentation];
			storableUTI = [image preferredFormatUTI];
			if ( (nil == storableData) || (nil == storableUTI) )
			{
				if ( nil != document )
				{
					NSString *localizedInformativeText = [NSString stringWithFormat:NSLocalizedString(@"Unable to convert image to preferred format. A placeholder may be substituted.","Alert Info")];
					[self displayMediaErrorAlertForWindow:[[document windowController] window]
										  informativeText:localizedInformativeText];
				}
				return nil;
			}
		}
		else
		{
			if ( nil != document )
			{
				NSString *localizedInformativeText = [NSString stringWithFormat:NSLocalizedString(@"Unable to create image from underlying data. A placeholder may be substituted.","Alert Info")];
				[self displayMediaErrorAlertForWindow:[[document windowController] window]
									  informativeText:localizedInformativeText];
			}
			return nil;
		}
	}
	
	// calculate digest
	NSString *mediaDigest = [storableData partiallyDigestString];
	
	// lock context
	[aContext lockPSCAndSelf];
	
	// find or create media using digest
	KTMedia *media = nil;
	
	if ( [mediaDigest length] > 0 )
	{
		media = [aContext objectMatchingMediaDigest:mediaDigest thumbnailDigest:nil];
		if ( nil != media )
		{
			TJT((@"+mediaWithData: will use pre-existing media %@", [media name]));
			[aContext unlockPSCAndSelf];
			return media;
		}
	}
	
	media = [NSEntityDescription insertNewObjectForEntityForName:@"Media" inManagedObjectContext:aContext];
	if ( nil != media )
	{		
		// we need a uniqueID first!
        [media setUniqueID:[[media document] nextUniqueID]];
		NSAssert((nil != [media valueForKey:@"uniqueID"]), @"media has nil uniqueID");
		//TJT((@"+mediaWithData: creating new media %@", [media uniqueID]));

		// we need a unique name, before we do *anything* else
		NSString *uniqueName = aName;
		
		// start by setting name from value passed in, or from filename
		if ( nil != uniqueName )
		{
			// remove any spaces or other bad guys in the name
			uniqueName = [uniqueName legalizeURLNameWithFallbackID:[media uniqueID]];
			
			// make sure uniqueName is actually unique
			// Only do this call if we *have* a media manager; it may not have been created yet.
			if ( nil != document && nil != [document oldMediaManager])
			{
				uniqueName = [[document oldMediaManager] uniqueNameWithName:uniqueName managedObjectContext:aContext];
			}
		}
		else
		{
			uniqueName = [NSString stringWithFormat:@"media%@", [media uniqueID]];
		}
		
		// set name
		[media setName:uniqueName];

		// KTMediaCopyContentsStorage is assumed, an alias makes no sense here
		// if we someday support storing the data in an external file, we can open this back up
		// to the passed in aStorageType
		[media setStorageType:KTMediaCopyContentsStorage];
		
		// store the data
		KTManagedObject *storage = [NSEntityDescription insertNewObjectForEntityForName:@"MediaData"
																 inManagedObjectContext:aContext];
		if ( nil == storage )
		{
			NSLog(@"error: unable to create MediaData object.");
			[aContext deleteObject:media];
			[aContext unlockPSCAndSelf];
			return nil;
		}
		[storage setValue:storableData forKey:@"contents"];
        [media setValue:[NSNumber numberWithUnsignedInt:[storableData length]] forKey:@"mediaDataLength"];
		[media setMediaData:storage];
		[media setMediaUTI:storableUTI];
		
		// store digest as hash for uniqueing between contexts
		if ( [mediaDigest length] > 0 )
		{
			[media setValue:mediaDigest forKey:@"mediaDigest"];
			[media setValue:mediaDigest forKeyPath:@"mediaData.digest"];
		}    
						
		// set our creation date to now
		[media setOriginalCreationDate:[NSCalendarDate calendarDate]];
		
		// prepopulate cached images
		[media prepopulateCachedImages];

		// we inserted some new objects, we might need to save them
		//[[media document] saveContext:(KTManagedObjectContext *)[media managedObjectContext] onlyIfNecessary:YES];
	}
	else
	{
		NSLog(@"error: unable to create Media object from data.");
		[aContext unlockPSCAndSelf];
		return nil;
	}
	
	[aContext unlockPSCAndSelf];
	return media;
}

+ (BOOL)shouldConvertOriginalWithUTI:(NSString *)aUTI
{
	if ( [NSString UTI:aUTI conformsToUTI:(NSString *)kUTTypeImage]
		 && ![NSString UTI:aUTI isEqualToUTI:(NSString *)kUTTypeJPEG]
		 && ![NSString UTI:aUTI isEqualToUTI:(NSString *)kUTTypePNG]
		 && ![NSString UTI:aUTI isEqualToUTI:(NSString *)kUTTypeGIF] )
	{
		return YES;
	}
	else
	{
		return NO;
	}
}

+ (KTMedia *)mediaWithImage:(NSImage *)anImage
					   name:(NSString *)aName
	  uniformTypeIdentifier:(NSString *)aUTI
		insertIntoManagedObjectContext:(KTManagedObjectContext *)aContext
{
	id result = [self mediaWithData:[anImage preferredRepresentation]
							   name:aName
			  uniformTypeIdentifier:aUTI
	 insertIntoManagedObjectContext:aContext];
	return result;
}

+ (KTMedia *)mediaWithPasteboard:(NSPasteboard *)aPboard
				  pasteboardType:(id)aPboardtype
					 storageType:(KTMediaStorageType)aStorageType
		insertIntoManagedObjectContext:(KTManagedObjectContext *)aContext
{
	return nil;
}

- (void)prepopulateCachedImages
{
	if ( [self isImage] )
	{
		// do we need _inTextMedium?
		
		// do we need _large?
		
		// do we need _thumbnail?
	}
}

#pragma mark awake
	
- (void)awakeFromFetch
{
	[super awakeFromFetch];
	[self setCachedIcons:[NSMutableDictionary dictionary]];
	[self setInspectorImage:nil];
	[self setSubstitutableImageNames:[NSMutableSet set]];
}

- (void)awakeFromInsert
{
	[super awakeFromInsert];
	[self setCachedIcons:[NSMutableDictionary dictionary]];
	[self setInspectorImage:nil];
	[self setSubstitutableImageNames:[NSMutableSet set]];
}

#pragma mark dealloc

/// Case 18430: we only want to remove observers on main thread
- (void)removeObservers
{
	if ( [NSThread isMainThread] )
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self];
	}
	else
	{
		[self performSelectorOnMainThread:@selector(removeObservers)
							   withObject:nil
							waitUntilDone:NO];
	}
}

- (void)didTurnIntoFault
{
	if ([self storageType] == KTMediaPlaceholderStorage)
	{
		[self removeObservers];
	}
	
	[self setInspectorImage:nil];
	[self setSubstitutableImageNames:nil];
    [self setCachedIcons:nil];
	
	[self setPosterImage:nil];
	
	[super didTurnIntoFault];
}

- (void)clearMediaCaches:(NSNotification *)aNotification
{
	[self setCachedIcons:[NSMutableDictionary dictionary]];
	
    // what's really happening here is that the Design changed, so anything with placeholders should update
	NSArray *allCachedImages = [self allCachedImages];
	if ( nil != allCachedImages )
	{
		NSEnumerator *e = [allCachedImages objectEnumerator];
		KTCachedImage *cachedImage;
		while ( cachedImage = [e nextObject] )
		{
			if ( [cachedImage substituteOriginal] )
			{
				[cachedImage recalculateSize];
			}
			else // if ( [cachedImage hasValidCacheFile] )
			{
				[cachedImage removeCacheFile]; // will also check if cache file exits
			}
		}
	}
}

#pragma mark copying

- (KTManagedObject *)copyToContext:(KTManagedObjectContext *)aContext
{
	NSAssert(![[[self managedObjectContext] persistentStoreCoordinator] isEqual:[aContext persistentStoreCoordinator]],
			 @"persistentStoreCoordinators should be different, or the locks will deadlock");
	
	[self lockPSCAndMOC];
	[aContext lockPSCAndSelf];
	
	// create a copy of this object in aContext
	KTMedia *newMedia = [NSEntityDescription insertNewObjectForEntityForName:@"Media"
													  inManagedObjectContext:aContext];
	
	// copy attributes
	[newMedia copyAttributesFromObject:self];
	
	// copy image relationships	
	KTManagedObject *mediaData = [self valueForKey:@"mediaData"];
	if ( nil != mediaData )
	{
		KTManagedObject *newMediaData = [newMedia valueForKey:@"mediaData"];
		if ( nil == newMediaData )
		{
			newMediaData = [NSEntityDescription insertNewObjectForEntityForName:@"MediaData"
														 inManagedObjectContext:aContext];
            [newMedia setMediaData:newMediaData];
		}
		[newMediaData setValue:[mediaData valueForKey:@"contents"] forKey:@"contents"];
		[newMediaData setValue:[mediaData valueForKey:@"digest"] forKey:@"digest"];
	}
	
	KTManagedObject *thumbnailData = [self valueForKey:@"thumbnailData"];
	if ( nil != thumbnailData )
	{
		KTManagedObject *newThumbnailData = [newMedia valueForKey:@"thumbnailData"];
		if ( nil == newThumbnailData )
		{
			newThumbnailData = [NSEntityDescription insertNewObjectForEntityForName:@"ThumbnailData"
															 inManagedObjectContext:aContext];
            [newMedia setThumbnailData:newThumbnailData];
		}
		[newThumbnailData setValue:[thumbnailData valueForKey:@"contents"] forKey:@"contents"];
		[newThumbnailData setValue:[thumbnailData valueForKey:@"digest"] forKey:@"digest"];
	}
	
	// copy storage relationships
	/*	Mike: Defunct in 1.5
	KTStoredDictionary *fileAttributes = [self valueForKey:@"fileAttributes"];
	if ( nil != fileAttributes )
	{
		KTStoredDictionary *newFileAttributes = [newMedia valueForKey:@"fileAttributes"];
		if ( nil == newFileAttributes )
		{
			newFileAttributes = [KTStoredDictionary dictionaryInManagedObjectContext:aContext entityName:@"FileAttributesDictionary"];
			[newMedia setValue:newFileAttributes forKey:@"fileAttributes"];
		}
		[newFileAttributes addEntriesFromDictionary:fileAttributes];
	}
	
	
	KTStoredDictionary *metadata = [self valueForKey:@"metadata"];
	if ( nil != metadata )
	{
		KTStoredDictionary *newMetadata = [newMedia valueForKey:@"metadata"];
		if ( nil == newMetadata )
		{
			newMetadata = [KTStoredDictionary dictionaryInManagedObjectContext:aContext entityName:@"MetadataDictionary"];
			[newMedia setValue:newMetadata forKey:@"metadata"];
		}
		[newMetadata addEntriesFromDictionary:metadata];
	}
	*/
	
	// we inserted a new object, we might need to save it
	//[[newMedia document] saveContext:(KTManagedObjectContext *)[newMedia managedObjectContext] onlyIfNecessary:YES];

	[aContext unlockPSCAndSelf];
	[self unlockPSCAndMOC];
	
	return newMedia;
}

- (NSPredicate *)predicateForSimilarObject 
{
	// if we have separate thumbnailData, we'll unique on both digests
	// otherwise, just unique on mediaDigest
	if ( nil != [self valueForKey:@"thumbnailDigest"] )
	{
		return [NSPredicate predicateWithFormat:@"(mediaDigest like %@) && (thumbnailDigest like %@)", [self wrappedValueForKey:@"mediaDigest"], [self wrappedValueForKey:@"thumbnailDigest"]];
	}
	else
	{
		return [NSPredicate predicateWithFormat:@"mediaDigest like %@", [self wrappedValueForKey:@"mediaDigest"]];
	}
}

#pragma mark -

/*! returns name.extension, where extension is derived from originalPath or UTI */
- (NSString *)fileName
{
	NSString *name = [self name];
	NSString *extension = nil;
    
    NSString *originalPath = [self wrappedValueForKey:@"originalPath"];
    if ( nil != originalPath )
    {
        extension = [[originalPath lastPathComponent] pathExtension];
    }
    
    if ( nil == extension )
    {
        [NSString filenameExtensionForUTI:[self mediaUTI]];
    }
        
	if ( nil != extension )
	{
		NSAssert([name length], @"Trying to append to an empty string");
		name = [name stringByAppendingPathExtension:extension];
	}
	//TJT((@"media fileName => %@", name));
	return name;
}

/*! returns name_tag.extension, where tag is discovered by lookup */
- (NSString *)fileNameForImageName:(NSString *)anImageName
{
	if ( nil == anImageName )
	{
		return [self fileName];
	}
	
	if ( [anImageName isEqualToString:@"originalAsImage"] )
	{
		return [self fileName];
	}
	
	NSDictionary *typeInfo = [KTDesign infoForMediaUse:anImageName];
	
	// if a fileName is specified, just use that
	if ( nil != [typeInfo valueForKey:@"fileName"] )
	{
		return [typeInfo valueForKey:@"fileName"];
	}
	
	// if substitute original, use that
	if ( [self substituteOriginalForImageName:anImageName] )
	{
		return [self fileName];
	}
	
	// will be a CachedImage, compute name_tag.extension
	NSString *result = [self name];
	NSString *tag = [typeInfo valueForKey:@"tag"];
	NSString *extension = [typeInfo valueForKey:@"fileExtension"];
	
	// if we have a tag, append the tag (and we *should* have a tag)
	if ( nil != tag )
	{
		result = [result stringByAppendingString:[NSString stringWithFormat:@"_%@", tag]];
	}
	
	
	// PROBLEM: IF MEDIA'S mediaUTI is PNG, THIS WILL CHOOSE JPEG EVEN THOUGH THE DATA ARE PNG.
	// WE REALLY NEED TO LOOK AT THE ACTUAL MEDIA, NOT THE PREFERRED EXTENSION.
	// Maybe the real problem is that we're trying to force some particular extension based on content,
	// but without actually converting the data?
	//
	// I'M TRYING THIS, BORROWING FROM METHOD ABOVE.
    if ( nil == extension )
    {
		extension = [NSString filenameExtensionForUTI:[[self cachedImageForImageName:anImageName] formatUTICachingIfNecessary]];
    }
	
	// if we don't have an extension, we should be able to determine it looking only at ourselves
	if ( nil == extension )
	{
		// if the preferred format is png, then it is png
		if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"KTPrefersPNGFormat"] )
		{
			extension = [NSString filenameExtensionForUTI:(NSString *)kUTTypePNG];
		}
		
		// if the preferred format is jpeg, then it is jpeg unless we have transparency
		// but if our original image was jpeg, then we know it won't be transparent
		else
		{
			// we're we originally jpeg?
			if ( [[self mediaUTI] isEqualToString:(NSString *)kUTTypeJPEG] )
			{
				extension = [NSString filenameExtensionForUTI:(NSString *)kUTTypeJPEG];
			}
			else
			{
				// we need to determine if we have alpha to preserve
				// We make a small (128) thumbnail, which should be enough to determine if there is alpha
				if ( [[self imageConvertedFromDataOfThumbSize:128] hasAlphaComponent] )
				{
					extension = [NSString filenameExtensionForUTI:(NSString *)kUTTypePNG];
				}
				else
				{
					extension = [NSString filenameExtensionForUTI:(NSString *)kUTTypeJPEG];
				}
			}
		}
	}
	
	// we should now have an extension, append it
	if ( nil != extension )
	{
		result = [result stringByAppendingPathExtension:extension];
	}
	
	return result;
}

- (NSString *)imageNameForFileName:(NSString *)aFileName
{
    NSAssert((nil != aFileName), @"aFileName should not be nil");
    
    NSString *result = nil;
    
    // first, remove any file extension
    NSString *fileNameNoExtension = [aFileName stringByDeletingPathExtension];
    
    // next, remove [self name]_
    NSString *nameWithUnderscore = [[self name] stringByAppendingString:@"_"];
    
    // next, scan for nameWithUnderscore
    NSRange range = [fileNameNoExtension rangeOfString:nameWithUnderscore];
    if ( range.location != NSNotFound )
    {
        // find the tag
        NSString *tag = [fileNameNoExtension substringFromIndex:range.length];
        if ( [result isEqualToString:@""] )
        {
            result = nil;
        }
        // reverse lookup
        result = [self imageNameForTag:tag];
    }
    
    return result;
}

#pragma mark media path

- (NSString *)mediaPathRelativeTo:(KTPage *)aPage forFileName:(NSString *)aFileName allowFile:(BOOL)allowFlag
{
    NSString *result = nil;
    
	switch ( (int)[[self document] publishingMode] )
	{
		// in the case of kGeneratingPreview, we can use a file:// URL
		// for things like movies and images but we must use
		// _Media/<name> for all other media
		// NB: we can't return a media:// URL as the document ID will change between sessions!
		case kGeneratingPreview:
		{
			// Threaded Version

			// return _Media relative path, but don't trim ?ref= from the string
			NSString *mediaAbsolutePath = [[[[self document] rootAbsolutePath:(KTManagedObjectContext *)[aPage managedObjectContext]] stringByAppendingPathComponent:[[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultMediaPath"]] stringByAppendingPathComponent:aFileName];
			return [mediaAbsolutePath pathRelativeTo:[aPage absolutePathAllowingIndexPage:NO]];
			break;
			/*
			 non threaded version
			 
			if ( allowFlag )
            {
                // does aFileName refer to a scaled image?
                KTCachedImage *cachedImage = nil;
                NSString *imageName = [self imageNameForFileName:aFileName];
                if ( nil != imageName )
                {
                    cachedImage = [self cachedImageForImageName:imageName];
                }
                if ( (nil != cachedImage) && [cachedImage hasValidCacheFile] )
                {
                    // return fileURL to cache file
                    return [[NSURL fileURLWithPath:[cachedImage cacheAbsolutePath]] absoluteString];
                }
                
                // do we otherwise have an alias for it? (typical case = movie)
                NSString *dataFilePath = [self dataFilePath];
                if (nil != dataFilePath)
                {
                    // return fileURL to dataFilePath
                    return [[NSURL fileURLWithPath:dataFilePath] absoluteString];
                }
            }
			
			// return _Media relative path, but don't trim ?ref= from the string
			NSString *mediaAbsolutePath = [[[[self document] rootAbsolutePath:[self managedObjectContext]] stringByAppendingPathComponent:[[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultMediaPath"]] stringByAppendingPathComponent:aFileName];
			return [mediaAbsolutePath pathRelativeTo:[aPage absolutePathAllowingIndexPage:NO]];
			break;*/
		}
		default:
		{
			// return _Media relative path
			NSString *mediaAbsolutePath = [[[[self document] rootAbsolutePath:(KTManagedObjectContext *)[self managedObjectContext]] stringByAppendingPathComponent:
				[[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultMediaPath"]] stringByAppendingPathComponent:aFileName];
			result = [mediaAbsolutePath pathRelativeTo:[aPage absolutePathAllowingIndexPage:NO]];
			
			// strip off ?ref= info, if present
			NSRange refRange = [result rangeOfString:@"?ref="];
			if ( refRange.location != NSNotFound )
			{
				result = [result substringToIndex:refRange.location];
			}
			break;
		}
	}
	
    return result; // only used in default case
}

- (NSString *)enclosurePathRelativeTo:(KTPage *)aPage forFileName:(NSString *)aFileName allowFile:(BOOL)allowFlag
{
    NSString *result = nil;
    
	switch ( (int)[[self document] publishingMode] )
	{
		// in the case of kGeneratingPreview, we can use a file:// URL
		// for things like movies and images but we must use
		// _Media/<name> for all other media
		// NB: we can't return a media:// URL as the document ID will change between sessions!
		case kGeneratingPreview:
		{
			// Threaded Version
			
			// return _Media relative path, but don't trim ?ref= from the string
			NSString *mediaAbsolutePath = [[[[self document] rootAbsolutePath:(KTManagedObjectContext *)[aPage managedObjectContext]] stringByAppendingPathComponent:[[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultMediaPath"]] stringByAppendingPathComponent:aFileName];
			return [mediaAbsolutePath pathRelativeTo:[aPage absolutePathAllowingIndexPage:NO]];
			break;
		}
		default:
		{
			// return _Media relative path
			NSString *mediaAbsolutePath = [[[[self document] rootAbsolutePath:(KTManagedObjectContext *)[self managedObjectContext]] stringByAppendingPathComponent:
				[[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultMediaPath"]] stringByAppendingPathComponent:aFileName];
			result = [mediaAbsolutePath pathRelativeTo:[aPage absolutePathAllowingIndexPage:NO]];
			
			// strip off ?ref= info, if present
			NSRange refRange = [result rangeOfString:@"?ref="];
			if ( refRange.location != NSNotFound )
			{
				result = [result substringToIndex:refRange.location];
			}
			break;
		}
	}
	
    return result; // only used in default case
}

- (NSString *)mediaPathRelativeTo:(KTPage *)aPage forImageName:(NSString *)anImageName allowFile:(BOOL)allowFlag
{	
	if ( nil == anImageName )
	{
		return [self mediaPathRelativeTo:aPage];
	}
	
	NSString *fileName = [self fileNameForImageName:anImageName];
	NSString *mediaPath = [self mediaPathRelativeTo:aPage forFileName:fileName allowFile:allowFlag];
	return mediaPath;
}

- (NSString *)enclosurePathRelativeTo:(KTPage *)aPage forImageName:(NSString *)anImageName allowFile:(BOOL)allowFlag
{	
	if ( nil == anImageName )
	{
		return [self enclosurePathRelativeTo:aPage];
	}
	
	NSString *fileName = [self fileNameForImageName:anImageName];
	NSString *mediaPath = [self enclosurePathRelativeTo:aPage forFileName:fileName allowFile:allowFlag];
	return mediaPath;
}

/*! return URL as NSString */
- (NSString *)mediaPathRelativeTo:(KTPage *)aPage
{
	NSString *fileName = [self fileName];
	NSString *result = [self mediaPathRelativeTo:aPage forFileName:fileName allowFile:YES];
	return result;
}

- (NSString *)enclosurePathRelativeTo:(KTPage *)aPage
{
	NSString *fileName = [self fileName];
	NSString *result = [self enclosurePathRelativeTo:aPage forFileName:fileName allowFile:YES];
	return result;
}

// Used for RSS feed; we need the URL where the image is found
- (NSString *)publishedURL
{
	/// we now implement -publishedURL in KTMediaRef so that we can find appropriateScaledImage if isImage
	/// this is here as a backstop
	NSString *result = [NSString stringWithFormat:@"%@%@/%@", [[self document] publishedSiteURL],
		[[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultMediaPath"],
		[self fileName]];
	return result;
}

- (NSString *)publishedURLForImageName:(NSString *)anImageName
{
	NSString *result = [NSString stringWithFormat:@"%@%@/%@", [[self document] publishedSiteURL],
		[[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultMediaPath"],
		[self fileNameForImageName:anImageName]];
	return result;
}

#pragma mark thumbnail data

/*! if media has specially set thumbnail, remove it */
- (void)removeThumbnail
{
    KTManagedObject *thumbnailData = [self thumbnailData];
    if ( nil != thumbnailData )
    {
		KTManagedObjectContext *context = (KTManagedObjectContext *)[self managedObjectContext];
		[context lockPSCAndSelf];
        [context deleteObject:thumbnailData];
        thumbnailData = nil;
        [self setValue:nil forKey:@"thumbnailDataLength"];
        [self setValue:nil forKey:@"thumbnailDigest"];
        [self setValue:nil forKey:@"thumbnailUTI"];
		//[[self document] saveContext:context onlyIfNecessary:NO];
		[context unlockPSCAndSelf];
    }
	
}

/*! if media has scaled thumbnailImage CachedImage, remove it */
- (void)removeThumbnailImage
{
    BOOL hasThumbnail = [self hasCachedImageForImageName:@"thumbnailImage"];
    if ( hasThumbnail )
    {
		KTManagedObjectContext *context = (KTManagedObjectContext *)[self managedObjectContext];
		[context lockPSCAndSelf];
		KTCachedImage *cachedImage = [self cachedImageForImageName:@"thumbnailImage"];
		[context deleteObject:cachedImage];
		//[[self document] saveContext:(KTManagedObjectContext *)[self managedObjectContext] onlyIfNecessary:NO];
		[context unlockPSCAndSelf];
    }
}

/*! this is the workhorse, all setThumbnail* methods should feed through here */
- (void)setThumbnailWithData:(NSData *)aData
{
	if ( nil == aData )
	{
		[NSException raise:kKTMediaException format:@"%@ data is nil", _cmd];
		return;
	}
		
	// start off not allowing filename substitution for thumbnailImage
	[[self substitutableImageNames] removeObject:@"thumbnailImage"];
	
	KTManagedObjectContext *context = (KTManagedObjectContext *)[self managedObjectContext];
	[context lockPSCAndSelf];
	
	// make sure we have a storage object for the data
	if ( nil == [self thumbnailData] )
	{
        KTManagedObject *newThumbnailData = [NSEntityDescription insertNewObjectForEntityForName:@"ThumbnailData" 
                                                                       inManagedObjectContext:context];		
		[self setThumbnailData:newThumbnailData];
	}
	
	// take the data and make a scaled PNG out of it, whatever it is

	NSDictionary *typeInfo = [KTDesign infoForMediaUse:@"thumbnailImage"];
	unsigned int width = [[typeInfo valueForKey:@"maxWidth"] intValue];
	unsigned int height  = [[typeInfo valueForKey:@"maxHeight"] intValue];
	
	NSImage *thumbnailImage = [[[NSImage alloc] initWithData:aData ofMaximumSize:MAX(width,height)] autorelease];
	

	NSImage *scaledImage = [thumbnailImage imageWithMaxWidth:width 
													  height:height 
													behavior:[self scalingBehaviorForKey:[typeInfo valueForKey:@"behavior"]]
												   alignment:[self imageAlignmentForKey:[typeInfo valueForKey:@"alignment"]]];
	
	NSData *thumbnailData = [scaledImage PNGRepresentation];
	
	// store the new thumbnail stuff
	[self setValue:thumbnailData forKeyPath:@"thumbnailData.contents"];
	[self setValue:[thumbnailData partiallyDigestString] forKeyPath:@"thumbnailData.digest"];
	[self setValue:[thumbnailData partiallyDigestString] forKey:@"thumbnailDigest"];
	[self setValue:(NSString *)kUTTypePNG forKey:@"thumbnailUTI"];
	
	// we inserted a new object, we might need to save it
	//[[self document] saveContext:context onlyIfNecessary:YES];

	[context unlockPSCAndSelf];
}

- (void)setThumbnailWithContentsOfFile:(NSString *)aPath
{
	NSData *data = [NSData dataWithContentsOfFile:aPath];
	
	if ( nil != data )
	{
		[self setThumbnailWithData:data];
	}
	else
	{
		[NSException raise:kKTMediaException format:@"Unable to get image at path %@", aPath];
	}
}

- (void)setThumbnailWithImage:(NSImage *)anImage
{
	if ( nil != anImage )
	{
		[self setThumbnailWithData:[anImage PNGRepresentation]];
	}
	else
	{
		[NSException raise:kKTMediaException format:@"%@ image is nil", _cmd];
	}
}

- (void)setThumbnailWithDataSourceDictionary:(NSDictionary *)aDataSourceDictionary
{
	NSData *data = nil;
	// Reading from a file is highest priority
	if ( nil != [aDataSourceDictionary valueForKey:kKTDataSourceFilePath] )
	{	
		data = [NSData dataWithContentsOfFile:[aDataSourceDictionary valueForKey:kKTDataSourceFilePath]];
	}
	// Original data has next priority
	else if ( nil != [aDataSourceDictionary objectForKey:kKTDataSourceData] )
	{
		data = [aDataSourceDictionary objectForKey:kKTDataSourceData];
	}
	// image is lowest priority
	else if ( nil != [aDataSourceDictionary objectForKey:kKTDataSourceImage] )
	{
		data = [[aDataSourceDictionary objectForKey:kKTDataSourceImage] preferredRepresentation];
	}

	[self setThumbnailWithData:data];
}

- (void)setThumbnailFromMedia
{
	NSData *mediaData = [self data];
	[self setThumbnailWithData:mediaData];
}

#pragma mark accessors

- (NSMutableDictionary *)cachedIcons
{
	return myCachedIcons;
}

- (void)setCachedIcons:(NSMutableDictionary *)aDictionary
{
	[aDictionary retain];
	[myCachedIcons release];
	myCachedIcons = aDictionary;
}
 
// FIXME: there's a binding here that went away and needs to be fixed!
// this is just for bindings
//- (NSArray *)cachedImagesAsArray
//{
//	return [myCachedMediaImages allValues];
//}

- (NSImage *)inspectorImage
{
    return myInspectorImage;
}

- (void)setInspectorImage:(NSImage *)anImage
{
	[anImage retain];
	[myInspectorImage release];
	myInspectorImage = anImage;
}

#pragma mark accessors (derived)

/*!	If the data lives in a file, return the path to that file.  Return nil if not supported.
*/
- (NSString *)dataFilePath
{
	NSString *result = nil;
	
	BDAlias *alias = [self dataFileAlias];
	if ( nil != alias )
	{
		result = [alias fullPathRelativeToPath:[NSHomeDirectory() stringByResolvingSymlinksInPath]];
	}
	if ( NSNotFound != [result rangeOfString:@".Trash"].location )
	{
		result = nil;		// in trash -- act as if it's deleted
	}
	
	return result;
}

- (BDAlias *)dataFileAlias;
{
	BDAlias *result = nil;
	
	[self lockPSCAndMOC];
	
	switch ([self storageType])
	{
		case KTMediaCopyAliasStorage:
		{
			// Unarchive the alias from stored data
			NSData *currentData = [self threadSafeValueForKeyPath:@"mediaData.contents"];
			result = [BDAlias aliasWithData:currentData];
			
			[result fullPath];	// Force the alias to resolve and update it if changed
			NSData *newData = [result aliasData];
			if (![currentData isEqualToData:newData])
			{
				[self threadSafeSetValue:newData forKeyPath:@"mediaData.contents"];
			}
		}
			
		case KTMediaCopyFileStorage:
			// MAYBE WORTHWHILE IN THE FUTURE?
			
			//[NSException raise:kKTMediaException format:@"KTMediaCopyFileStorage is unsupported in this release."];
			break;
			
		default:
			;
	}
	
	[self unlockPSCAndMOC];
	
	return result;
}

- (int)dataLength
{
	return [[self data] length];
}

/*! returns original contents as NSData */
- (NSData *)data
{
	@synchronized ( self ) // we lock on self, too, so that we don't change any values while fetching data
	{
		switch ( [self storageType] )
		{
			case KTMediaCopyContentsStorage:
			{
				NSData *contents = nil;
				@try
				{
					KTManagedObject *mediaData = [self wrappedValueForKey:@"mediaData"];
					contents = [mediaData wrappedValueForKey:@"contents"];
				}
				@catch (NSException *exception)
				{
					NSLog(@"asking mediaData.contents for %@ threw exception, name:%@ reason:%@", 
						  [self name], [exception name], [exception reason]);
					contents = nil;
				}	
				@finally
				{
					return contents;
				}
				break;
			}
			case KTMediaCopyAliasStorage:
			{
				BDAlias *alias = [self dataFileAlias];
				NSString *path = nil;
				if ( nil != alias )
				{
					path = [alias fullPathRelativeToPath:[NSHomeDirectory() stringByResolvingSymlinksInPath]];
				}
				if ( NSNotFound != [path rangeOfString:@".Trash"].location )
				{
					path = nil;		// in trash -- act as if it's deleted
				}
				
				if ( (nil != path) && [[NSFileManager defaultManager] fileExistsAtPath:path] )
				{
					return [NSData dataWithContentsOfFile:path];
				}
				else
				{
					// file is missing!
					if ( kGeneratingPreview == [[self document] publishingMode] )
					{
						//  ask user to find it (on the main thread)
						NSDictionary *infoDict = [NSDictionary dictionaryWithObject:[self objectID] forKey:@"objectID"];
						[[self document] performSelectorOnMainThread:@selector(locateMissingMedia:) 
														  withObject:infoDict 
													   waitUntilDone:NO];
					}
					
					//  but return a ? icon for display first
					return [[NSImage qmarkImage] preferredRepresentation];
				}
				break;
			}
			case KTMediaPlaceholderStorage:
			{
				/// find designBundleIdentifier by locating the selectedPage in the media's context
				KTPage *selPage = [[[self document] windowController] selectedPage];
				NSManagedObjectID *selPageID = [selPage objectID];
				KTPage *selPageInThisContext = (KTPage *)[[self managedObjectContext] objectWithID:selPageID];
				
				[self lockPSCAndMOC];
				NSString *designBundleIdentifier = [selPageInThisContext valueForKey:@"designBundleIdentifierInherited"];
				[self unlockPSCAndMOC];
				
				NSString *placeholderPath = nil;
				if ( nil != designBundleIdentifier )
				{
					placeholderPath = [[self document] placeholderImagePathForDesignBundleIdentifier:designBundleIdentifier];
				}
				if (nil != placeholderPath)
				{
					NSImage *image = [[[NSImage alloc] initWithContentsOfFile:placeholderPath] autorelease];
					[image normalizeSize];
					if (nil != image)
					{
						[image embossPlaceholder];
						return [image preferredRepresentation];
					}
				}
				else
				{
					// use fallback data stored at media creation
					KTManagedObject *mediaData = [self wrappedValueForKey:@"mediaData"];
					NSData *fallbackData = [mediaData wrappedValueForKey:@"contents"];
					NSImage *fallbackImage = [[[NSImage alloc] initWithData:fallbackData] autorelease];
					[fallbackImage normalizeSize];
					[fallbackImage embossPlaceholder];
					return [fallbackImage preferredRepresentation];
				}
				break;
			}
			case KTMediaCopyFileStorage:
				NSLog(@"error: KTMediaCopyFileStorage is unsupported in this release.");
				break;			
			default:
				break;
		}
	}
    
    NSLog(@"error: media %@ did not find suitable data -- this should not happen -- please report!", [self name]);
    return nil;
}

/*!	A string for bindings.  Not very efficient, but just for diagnostics
*/
- (NSString *)sizeString
{
	NSString *result = @"no size";
	NSImage *image = [[[NSImage alloc] initWithData:[self data]] autorelease];
	if (nil != image)
	{
		[image normalizeSize];
		result = [NSString stringWithFormat:@"Original Size: %.0f x %.0f", [image size].width, [image size].height];
	}
	return result;
}

- (NSString *)storageTypeString
{
	int offset = [self storageType] - KTMediaCopyAliasStorage;
	NSArray *abbrevs = [NSArray arrayWithObjects:@"Alias", @"Contents", @"File", @"Placeholder", nil];
	return [abbrevs objectAtIndex:offset];
}	

- (KTDocument *)document
{
	// we can figure out our document if we know our context
	KTDocument *document = (KTDocument *)[[NSDocumentController sharedDocumentController] documentForManagedObjectContext:[self managedObjectContext]];
	if ( nil == document )
	{
		TJT((@"warning: media \"%@\" is returning nil for -document. is this ok?", [self name]));
	}
	return document;
}

/*! returns whether object has separate thumbnailData */
- (BOOL)hasThumb
{
	return ( nil != [self thumbnailData]);
}

- (BOOL)isImage
{
	NSString *UTI = [self mediaUTI];
	
	if ( nil == UTI )
	{
		NSLog(@"error: %@ has no UTI", [self managedObjectDescription]);
		return NO;
	}
	
	return ( [NSString UTI:UTI conformsToUTI:(NSString *)kUTTypeImage] );
}

- (BOOL)isMovie
{
	NSString *UTI = [self mediaUTI];
	
	if ( nil == UTI )
	{
		NSLog(@"error: %@ has no UTI", [self managedObjectDescription]);
		return NO;
	}
	
	return ( [NSString UTI:UTI conformsToUTI:(NSString *)kUTTypeMovie] );
}


- (BOOL)isPlaceholder
{
	return ([self storageType] == KTMediaPlaceholderStorage);
}

//- (KTOldMediaManager *)mediaManager
//{
//	return [[self document] oldMediaManager];
//}

/*! returns MIME type by converting internally stored UTI for object */
- (NSString *)MIMEType
{
	NSString *UTI = [self mediaUTI];
	if ( nil != UTI )
	{
		return [NSString MIMETypeForUTI:UTI];
	}
	else
	{
		NSLog(@"error: unable to determine MIMEType: no UTI for object %@", [self managedObjectDescription]);

		return @"";
	}
}

/*! returns preferred file extension by converting internally stored UTI for object */
- (NSString *)preferredFileExtension
{
	NSString *UTI = [self mediaUTI];
	if ( nil != UTI )
	{
		return [NSString filenameExtensionForUTI:UTI];
	}
	else
	{
		[NSException raise:kKTMediaException format:@"preferredFileExtension no UTI for object %@", self];
		return @"";
	}
}


/*! returns 32-bit number corresponding to the four "type" bytes of OS 9, if available */ 
- (OSType)OSType
{
	NSString *UTI = [self mediaUTI];
	if ( nil != UTI )
	{
		return [NSString OSTypeForUTI:UTI];
	}
	else
	{
		[NSException raise:kKTMediaException format:@"OSType no UTI for object %@", self];
		OSType noFileType = '----'; 
		return noFileType;
	}
}

#pragma mark accessors (NSFileAttributes)

- (id)fileAttribute:(id)anAttributeKey
{
	// FIXME: Must rewrite this code to pull attributes off the disk instead
	///return [[self fileAttributes] objectForKey:anAttributeKey];
	return nil;
}

- (NSDate *)creationDate
{
	return [self fileAttribute:NSFileCreationDate];
}

- (NSDate *)modificationDate
{
	return [self fileAttribute:NSFileModificationDate];
}

- (unsigned long long)fileSize
{
	return [[self fileAttribute:NSFileSize] unsignedLongLongValue];
}

- (BOOL)fileExtensionHidden
{
	return [[self fileAttribute:NSFileExtensionHidden] boolValue];
}

- (unsigned long)posixPermissions
{
	return [[self fileAttribute:NSFilePosixPermissions] unsignedLongValue];
}

- (unsigned long)ownerAccountID
{
	return [[self fileAttribute:NSFileOwnerAccountID] unsignedLongValue];
}

- (NSString *)ownerAccountName
{
	return [self fileAttribute:NSFileOwnerAccountName];
}

- (unsigned long)groupAccountID
{
	return [[self fileAttribute:NSFileGroupOwnerAccountID] unsignedLongValue];
}

- (NSString *)groupAccountName
{
	return [self fileAttribute:NSFileGroupOwnerAccountName];
}

#pragma mark -
#pragma mark core data attributes

- (NSString *)mediaDigest
{
	return [self wrappedValueForKey:@"mediaDigest"];
}

- (NSString *)mediaUTI 
{
	return [self wrappedValueForKey:@"mediaUTI"];
}

- (void)setMediaUTI:(NSString *)value 
{
	[self setWrappedValue:value forKey:@"mediaUTI"];
}

- (NSString *)name 
{
	return [self wrappedValueForKey:@"name"];
}

- (void)setName:(NSString *)value 
{
	[self setWrappedValue:value forKey:@"name"];
}

- (NSCalendarDate *)originalCreationDate 
{
	return [self wrappedValueForKey:@"originalCreationDate"];
}

- (void)setOriginalCreationDate:(NSCalendarDate *)value 
{
	[self setWrappedValue:value forKey:@"originalCreationDate"];
}

- (NSString *)originalPath 
{
	return [self wrappedValueForKey:@"originalPath"];
}

- (void)setOriginalPath:(NSString *)value 
{
	[self setWrappedValue:value forKey:@"originalPath"];
}

- (KTMediaStorageType)storageType
{
    NSNumber *tmpValue = [self wrappedValueForKey:@"storageType"];    
    return [tmpValue shortValue];		// not an optional property, so it's OK to convert to a non-object
}
- (void)setStorageType:(KTMediaStorageType)value
{
 	[self setWrappedValue:[NSNumber numberWithShort:value] forKey:@"storageType"];
}

- (NSString *)thumbnailDigest
{
	return [self wrappedValueForKey:@"thumbnailDigest"];
}

- (NSString *)thumbnailUTI 
{
	return [self wrappedValueForKey:@"thumbnailUTI"];
}

- (void)setThumbnailUTI:(NSString *)value 
{
	[self setWrappedValue:value forKey:@"thumbnailUTI"];
}

- (NSDictionary *)metadata
{
	return [self transientValueForKey:@"metadata" persistentPropertyListKey:@"metadataData"];
}

- (void)setMetadata:(NSDictionary *)metadata
{
	[self setTransientValue:metadata forKey:@"metadata" persistentPropertyListKey:@"metadataData"];
}

- (NSString *)uniqueID 
{
	return [self wrappedValueForKey:@"uniqueID"];
}

- (void)setUniqueID:(NSString *)value 
{
	[self setWrappedValue:value forKey:@"uniqueID"];
}

#pragma mark -
#pragma mark core data to-one relationships

/*	///Mike: Removed in 1.5
- (KTStoredDictionary *)fileAttributes 
{
	return [self wrappedValueForKey:@"fileAttributes"];
}

- (void)setFileAttributes:(KTStoredDictionary *)value 
{
    id oldFileAttributes = [[[self wrappedValueForKey:@"fileAttributes"] retain] autorelease];
    if ( ![oldFileAttributes isEqual:value] )
    {
		[self setWrappedValue:value forKey:@"fileAttributes"];
		[value setWrappedValue:self forKey:@"owner"];
        if ( [oldFileAttributes isManagedObject] )
        {
            [(KTManagedObjectContext *)[self managedObjectContext] threadSafeDeleteObject:oldFileAttributes];
        }
    }
}

- (void)setFileAttributesFromDictionary:(NSDictionary *)aDictionary
{
	KTStoredDictionary *attrs = [self fileAttributes];
	
	if ( nil != attrs )
	{
		NSEnumerator *e = [aDictionary keyEnumerator];
		id key;
		while ( key = [e nextObject] )
		{
			id object = [aDictionary objectForKey:key];
			[attrs setObject:object forKey:key];
		}
	}
	else
	{
		attrs = [KTStoredDictionary dictionaryWithDictionary:aDictionary 
									  inManagedObjectContext:(KTManagedObjectContext *)[self managedObjectContext]
												  entityName:@"FileAttributesDictionary"];
		[self setFileAttributes:attrs];
	}
} */

- (KTManagedObject *)mediaData
{
	return [self wrappedValueForKey:@"mediaData"];
}

- (void)setMediaData:(KTManagedObject *)value
{
    id oldMediaData = [[[self mediaData] retain] autorelease];
    if ( ![oldMediaData isEqual:value] )
    {
		[self setWrappedValue:value forKey:@"mediaData"];
		[value setWrappedValue:self forKey:@"media"];
        if ( [oldMediaData isManagedObject] )
        {
            [(KTManagedObjectContext *)[self managedObjectContext] threadSafeDeleteObject:oldMediaData];
        }
    }
}

- (KTManagedObject *)thumbnailData
{
	return [self wrappedValueForKey:@"thumbnailData"];
}

- (void)setThumbnailData:(KTManagedObject *)value
{
    id oldThumbnailData = [[[self thumbnailData] retain] autorelease];
    if ( ![oldThumbnailData isEqual:value] )
    {
		[self setWrappedValue:value forKey:@"thumbnailData"];
		[value setWrappedValue:self forKey:@"media"];
        if ( [oldThumbnailData isManagedObject] )
        {
            [(KTManagedObjectContext *)[self managedObjectContext] threadSafeDeleteObject:oldThumbnailData];
        }
    }
}

#pragma mark "original" image support

/*!	Returns an image from its data (original size) */
- (NSImage *)imageConvertedFromData
{
	NSImage *result = nil;
	// Not asking for the original, so first convert to an image if needed.
	if ( [self isImage] )
	{
		NSData *data = [self data];
		result = [[[NSImage alloc] initWithData:data] autorelease];
        [result normalizeSize];
	}
	else if ( [self isMovie] )
	{
		// we have to find the posterImage on the main thread
		result = [self posterImage];
	}
	else
	{
		result = [[NSWorkspace sharedWorkspace] iconImageForUTI:[self mediaUTI]];
	}
	
	return result;
}

// SAME AS ABOVE -- BUT GETS A THUMBNAIL

/*!	Returns an image from its data, but MAY scale down to the given size.
It might not scale it if doing so won't be much of a speed advantage. */

- (NSImage *)imageConvertedFromDataOfThumbSize:(int)aMaxSize;
{
	NSImage *result = nil;
	
	[self lockPSCAndMOC];
	
	@synchronized ( self ) // we lock on self, too, so that we don't change any values while fetching data
	{
		// Not asking for the original, so first convert to an image if needed.
		if ( [self isImage] )
		{
			switch ( [self storageType] )
			{
				case KTMediaCopyContentsStorage:
				{
					NSData *contents = nil;
					@try
					{
						KTManagedObject *mediaData = [self valueForKey:@"mediaData"];
						contents = [mediaData valueForKey:@"contents"];
					}
					@catch (NSException *exception)
					{
						NSLog(@"asking mediaData.contents for %@ threw exception, name:%@ reason:%@", 
							  [self name], [exception name], [exception reason]);
						contents = nil;
					}
					result = [[[NSImage alloc] initWithData:contents ofMaximumSize:aMaxSize] autorelease];
					break;
				}
				case KTMediaCopyAliasStorage:
				{
					BDAlias *alias = [self dataFileAlias];
					NSString *path = nil;
					if ( nil != alias )
					{
						path = [alias fullPathRelativeToPath:[NSHomeDirectory() stringByResolvingSymlinksInPath]];
					}
					if ( NSNotFound != [path rangeOfString:@".Trash"].location )
					{
						path = nil;		// in trash -- act as if it's deleted
					}
					
					if ( (nil != path) && [[NSFileManager defaultManager] fileExistsAtPath:path] )
					{
						result = [[[NSImage alloc] initWithContentsOfFile:path ofMaximumSize:aMaxSize] autorelease];
					}
					else
					{
						result = [NSImage qmarkImage];
					}
					break;
				}
				case KTMediaPlaceholderStorage:	// PLACEHOLDER -- DO NOT EMBOSS SINCE THIS IS A THUMB
				{
					/// find designBundleIdentifier by locating the selectedPage in the media's context
					KTPage *selPage = [[[self document] windowController] selectedPage];
					NSManagedObjectID *selPageID = [selPage objectID];
					KTPage *selPageInThisContext = (KTPage *)[[self managedObjectContext] objectWithID:selPageID];
					NSString *designBundleIdentifier = [selPageInThisContext valueForKey:@"designBundleIdentifierInherited"];
					
					NSString *placeholderPath = nil;
					if ( nil != designBundleIdentifier )
					{
						placeholderPath = [[self document] placeholderImagePathForDesignBundleIdentifier:designBundleIdentifier];
					}
					if (nil != placeholderPath)
					{
						result = [[[NSImage alloc] initWithContentsOfFile:placeholderPath ofMaximumSize:aMaxSize] autorelease];
					}
					else
					{
						// use fallback data stored at media creation
						NSData *fallbackData = [self valueForKeyPath:@"mediaData.contents"];
						result = [[[NSImage alloc] initWithData:fallbackData ofMaximumSize:aMaxSize] autorelease];
					}
					break;
				}
				case KTMediaCopyFileStorage:
					NSLog(@"error: KTMediaCopyFileStorage is unsupported in this release.");
					break;			
				default:
					break;
			}
		}
		else if ( [self isMovie] )
		{
			// we have to find the posterImage on the main thread
			result = [self posterImage];		// MAN WE REALLY SHOULD BE CACHING THIS!
		}
		else
		{
			result = [[NSWorkspace sharedWorkspace] iconImageForUTI:[self mediaUTI]];	// SCALE THIS TOO? OR NOT?
		}
	}//@synchronized
	
	[self unlockPSCAndMOC];
	
	return result;
}


- (void)setPosterImage:(NSImage *)aPosterImage
{
    [aPosterImage retain];
    [myPosterImage release];
    myPosterImage = aPosterImage;
}

- (NSImage *)posterImage
{
	if ( nil == myPosterImage )
	{
		NSAssert([self isMovie], @"media object should be a movie");

		NSDictionary *attributes = nil;
		NSString *filePath = [self dataFilePath];
		if (nil != filePath)	// try to get from file, so that we don't have to read in the data
		{
			attributes = [NSDictionary dictionaryWithObjectsAndKeys: 
					filePath, QTMovieFileNameAttribute,
					[NSNumber numberWithBool:NO], QTMovieOpenAsyncOKAttribute,
					nil];
		}
		else
		{
			QTDataReference *dataRef = [QTDataReference
dataReferenceWithReferenceToData:[self data]
							name:[self fileName] 
						MIMEType:[self MIMEType]];
			attributes = [NSDictionary dictionaryWithObjectsAndKeys: 
					dataRef, QTMovieDataReferenceAttribute,
					[NSNumber numberWithBool:NO], QTMovieOpenAsyncOKAttribute,
				nil];
		}
		
		[self performSelectorOnMainThread:@selector(computePosterImageFromMovieWithAttributes:) withObject:attributes
							waitUntilDone:YES];
		NSAssert((nil != myPosterImage), @"myPosterImage should not be nil");
	}
	
	return myPosterImage;
}

// From the information, just create movie and get poster image on main thread.
// This should work if context is locked; there's no data base access.

- (void)computePosterImageFromMovieWithAttributes:(NSDictionary *)aMovieAttributes
{	
	NSAssert([NSThread isMainThread], @"should not be calling from a background thread");
	
	NSError *error = nil;
	QTMovie *movie = [[[QTMovie alloc] initWithAttributes:aMovieAttributes error:&error] autorelease];
	
	if ( nil != movie )
	{
		[self setPosterImage:[movie betterPosterImage]];		// from iMedia 
	}
	else
	{
		[self setPosterImage:nil];
		// log to console so bug reports pick it up
		NSLog(@"error: unable to read movie for a thumbnail from %@: %@", 
			  [[aMovieAttributes description] condenseWhiteSpace],
			  [error localizedDescription]);
	}
	
	// Handle a missing thumbnail, like when we have a .wmv file
	if ( nil == myPosterImage || NSEqualSizes(NSZeroSize,[myPosterImage size]) )
	{
		NSString *path = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:@"com.apple.quicktimeplayer"];
		if (nil == path)
		{
			[self setPosterImage:[NSImage imageNamed:@"NSDefaultApplicationIcon"]];	// last resort!
		}
		else
		{
			[self setPosterImage:[[NSWorkspace sharedWorkspace] iconForFile:path] ];
		}
	}		

	NSAssert((nil != myPosterImage), @"myPosterImage should not be nil");
}

/*! returns NSSize of image representation of original */
- (NSSize)imageSize
{
    NSSize result = NSMakeSize(0,0);
    
    if ( [self isImage] )
    {
        // do we have something on disk we can work with?
        NSString *path = [self dataFilePath];
		CGImageSourceRef source = nil;
        if ( nil != path )
        {
			NSURL *url = [NSURL fileURLWithPath:path];
			source = CGImageSourceCreateWithURL((CFURLRef)url, NULL);
		}
		else
		{
			source = CGImageSourceCreateWithData((CFDataRef)[self data], NULL);
		}
		if (source)
		{
			NSDictionary *props = (NSDictionary *) CGImageSourceCopyPropertiesAtIndex(source,  0,  NULL );
				
			result = NSMakeSize([[props objectForKey:(NSString *)kCGImagePropertyPixelWidth] intValue],
								[[props objectForKey:(NSString *)kCGImagePropertyPixelHeight] intValue]);
			CFRelease(source);
			[props release];
		}
    }
    
    return result;
}


/*! return simple NSImage for inpector binding purposes */
- (NSImage *)bindableInspectorImage
{
    if ( nil == myInspectorImage )
    {
        if ( ![self isImage] )
        {
            [NSException raise:kKTMediaException format:@"original media object is not an image"];
        }
        
        NSImage *image = [[NSImage alloc] initWithData:[self data]];
        [image normalizeSize];
        [self setInspectorImage:image];
        [image release];
    }
    
    return myInspectorImage;
}

- (void)setBindableInspectorImage:(NSImage *)anImage
{
	;	// no-op; for binding purposes only
}

- (NSData *)TIFFRepresentation
{	
	return [[self bindableInspectorImage] TIFFRepresentation];
}

- (void)setTIFFRepresentation:(id)anObject
{
	;	// no-op; for binding purposes only
}

- (id)valueForUndefinedKey:(NSString *)aKey
{
	if ( [aKey hasSuffix:@"Image"] )
	{
		return [self imageForImageName:aKey];		
	}
	else
	{
		return [[self metadata] objectForKey:aKey];
	}
}

- (CIScalingBehavior)scalingBehaviorForKey:(NSString *)aKey
{
    if ( nil == aKey )
    {
        return kFitWithinRect;	// no key, return FitWithinRect
    }
    
    NSString *nocapskey = [aKey lowercaseString];
    
    if ( [nocapskey isEqualToString:@"automatic"] )
    {
        return kAutomatic;
    }
    else if ( [nocapskey isEqualToString:@"anamorphic"] )
    {
        return kAnamorphic;
    }
    else if ( [nocapskey isEqualToString:@"fitwithinrect"] )
    {
        return kFitWithinRect;
    }
    else if ( [nocapskey isEqualToString:@"coverrect"] )
    {
        return kCoverRect;
    }
    else if ( [nocapskey isEqualToString:@"croptorect"] )
    {
        return kCropToRect;
    }
    else
    {
        return kFitWithinRect;	// key unknown, return FitWithinRect
    }
}

- (NSImageAlignment)imageAlignmentForKey:(NSString *)aKey
{
    if ( nil == aKey )
    {
        return NSImageAlignCenter;	// no key, return NSImageAlignCenter
    }
    
    NSString *nocapskey = [aKey lowercaseString];
    
    if ( [nocapskey isEqualToString:@"center"] )
    {
        return NSImageAlignCenter;
    }
    else if ( [nocapskey isEqualToString:@"top"] )
    {
        return NSImageAlignTop;
    }
    else if ( [nocapskey isEqualToString:@"topleft"] )
    {
        return NSImageAlignTopLeft;
    }
    else if ( [nocapskey isEqualToString:@"topright"] )
    {
        return NSImageAlignTopRight;
    }
    else if ( [nocapskey isEqualToString:@"left"] )
    {
        return NSImageAlignLeft;
    }
    else if ( [nocapskey isEqualToString:@"bottom"] )
    {
        return NSImageAlignBottom;
    }
    else if ( [nocapskey isEqualToString:@"bottomleft"] )
    {
        return NSImageAlignBottomLeft;
    }
    else if ( [nocapskey isEqualToString:@"bottomright"] )
    {
        return NSImageAlignBottomRight;
    }
    else if ( [nocapskey isEqualToString:@"right"] )
    {
        return NSImageAlignRight;
    }
    else
    {
        return NSImageAlignCenter;	// key unknown, return NSImageAlignCenter
    }
}

#pragma mark support

+ (void)displayMediaErrorAlertForWindow:(NSWindow *)window informativeText:(NSString *)informativeText
{
	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Media Error","Alert Title")
									 defaultButton:NSLocalizedString(@"OK", "OK Button")
								   alternateButton:nil
									   otherButton:nil
						 informativeTextWithFormat:informativeText];
	
	[alert beginSheetModalForWindow:window
					  modalDelegate:self 
					 didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) 
						contextInfo:nil];
}

+ (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[[alert window] orderOut:nil];
}

@end


