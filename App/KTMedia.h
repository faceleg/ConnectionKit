//
//  KTMedia.h
//  KTComponents
//
//  Copyright (c) 2005-2006, Karelia Software. All rights reserved.
//
//  THIS SOFTWARE IS PROVIDED BY KARELIA SOFTWARE AND ITS CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//

#import "KTManagedObject.h"

#import "KT.h"

#import "CIImage+Karelia.h"


extern NSString *kKTMediaException;

@class KTDocument, KTManagedObject, KTAbstractElement, KTCachedImage, KTPage, KTStoredDictionary, KTStoredSet;
@class BDAlias;

@interface KTMedia : KTManagedObject
{
    NSMutableDictionary *myCachedIcons;             // not archived
	NSMutableSet		*mySubstitutableImageNames;	// not archived
	
	NSImage				*myInspectorImage;          // not archived
	BOOL				isCreatingSiteOutlineImage;
	
	NSImage				*myPosterImage;				// not archived, just for movies
}

+ (KTMediaStorageType)defaultStorageType;

#pragma mark convenience constructors

+ (KTMedia *)defaultFaviconForPage:(KTPage *)aPage;

/* this is the preferred contstuctor: storageType is derived from root's KTMediaCopyType */
+ (KTMedia *)mediaWithContentsOfFile:(NSString *)aPath insertIntoManagedObjectContext:(KTManagedObjectContext *)aContext;

+ (KTMedia *)mediaWithImage:(NSImage *)anImage insertIntoManagedObjectContext:(KTManagedObjectContext *)aContext;

+ (KTMedia *)mediaNotFoundMediaWithDocument:(KTDocument *)aDocument;

#pragma mark actual constructors

+ (KTMedia *)mediaWithDataSourceDictionary:(NSDictionary *)aDataSourceDictionary
		  insertIntoManagedObjectContext:(KTManagedObjectContext *)aContext;

+ (KTMedia *)mediaWithContentsOfFile:(NSString *)aPath
						 storageType:(KTMediaStorageType)aStorageType
	  insertIntoManagedObjectContext:(KTManagedObjectContext *)aContext;

+ (KTMedia *)mediaWithData:(NSData *)someData
					  name:(NSString *)aName
	 uniformTypeIdentifier:(NSString *)aUTI
				 insertIntoManagedObjectContext:(KTManagedObjectContext *)aContext;

+ (KTMedia *)mediaWithImage:(NSImage *)anImage
					   name:(NSString *)aName
	  uniformTypeIdentifier:(NSString *)aUTI
				  insertIntoManagedObjectContext:(KTManagedObjectContext *)aContext;

+ (KTMedia *)mediaWithPasteboard:(NSPasteboard *)aPboard
				  pasteboardType:(id)aPboardtype
					 storageType:(KTMediaStorageType)aStorageType
  insertIntoManagedObjectContext:(KTManagedObjectContext *)aContext;

#pragma mark URLs/paths

/*! returns document _Media/ path for aFileName */
- (NSString *)mediaPathRelativeTo:(KTPage *)aPage forFileName:(NSString *)aFileName allowFile:(BOOL)allowFlag;

/*! returns name.extension, where extension is derived from UTI */
- (NSString *)fileName;

/*! returns name_tag.extension, where tag is discovered by lookup */
- (NSString *)fileNameForImageName:(NSString *)anImageName;

/*! returns tag from name_tag.extension */
- (NSString *)imageNameForFileName:(NSString *)aFileName;

- (NSString *)mediaPathRelativeTo:(KTPage *)aPage forImageName:(NSString *)anImageName allowFile:(BOOL)allowFlag;

/*! returns URL as NSString */
- (NSString *)mediaPathRelativeTo:(KTPage *)aPage;

- (NSString *)enclosurePathRelativeTo:(KTPage *)aPage forFileName:(NSString *)aFileName allowFile:(BOOL)allowFlag;
- (NSString *)enclosurePathRelativeTo:(KTPage *)aPage forImageName:(NSString *)anImageName allowFile:(BOOL)allowFlag;
- (NSString *)enclosurePathRelativeTo:(KTPage *)aPage;

/*! return non-relative URL as NSString */
- (NSString *)publishedURL;
- (NSString *)publishedURLForImageName:(NSString *)anImageName;

#pragma mark thumbnail image

- (void)setThumbnailWithData:(NSData *)aData;
- (void)setThumbnailWithContentsOfFile:(NSString *)aPath;
- (void)setThumbnailWithImage:(NSImage *)anImage;

- (void)setThumbnailWithDataSourceDictionary:(NSDictionary *)aDataSourceDictionary;
- (void)setThumbnailFromMedia;

/*! if media has specially set thumbnailData, remove it */
- (void)removeThumbnail;

/*! if media has scaled thumbnailImage CachedImage, remove it */
- (void)removeThumbnailImage;

#pragma mark accessors

/*! returns dictionary, key = imageName, value = NSImage */
- (NSMutableDictionary *)cachedIcons;

- (NSImage *)posterImage;

#pragma mark accessors (derived)

/*! returns original contents as NSData */
- (NSData *)data;

/*!	If the data lives in a file, return the path to that file.  Return nil if not supported. */
- (NSString *)dataFilePath;
- (BDAlias *)dataFileAlias;

- (int)dataLength;

/*! returns [sharedDocumentController documentForManagedObjectContext:] */
- (KTDocument *)document;

/*! returns whether object has separate thumbnailData */
- (BOOL)hasThumb;

/*! returns whether object's UTI comforms to public.image */
- (BOOL)isImage;

/*! returns whether object's UTI conforms to kUTTypeMovie */
- (BOOL)isMovie;

/*! returns whether object's storageType is KTMediaPlaceholderStorage */
- (BOOL)isPlaceholder;

/*! return [[self document] mediaManager] */
//- (KTOldMediaManager *)mediaManager;

/*! returns MIME type by converting internally stored UTI for object */
- (NSString *)MIMEType;

/*! returns 32-bit integer corresponding to the four "type" bytes of OS 9, if available */ 
- (OSType)OSType;

/*! returns preferred file extension by converting internally stored UTI for object */
- (NSString *)preferredFileExtension;

#pragma mark accessors (NSFileAttributes)
 
- (id)fileAttribute:(id)anAttributeKey; // uses keys defined in NSFileManager Constants

- (NSDate *)creationDate;
- (NSDate *)modificationDate;
- (unsigned long long)fileSize;
- (BOOL)fileExtensionHidden;
- (unsigned long)posixPermissions;
- (unsigned long)ownerAccountID;
- (NSString *)ownerAccountName;
- (unsigned long)groupAccountID;
- (NSString *)groupAccountName;

#pragma mark -
#pragma mark core data attributes

- (NSString *)mediaUTI;
- (void)setMediaUTI:(NSString *)value;

- (NSString *)name;
- (void)setName:(NSString *)value;

- (NSCalendarDate *)originalCreationDate;
- (void)setOriginalCreationDate:(NSCalendarDate *)value;

- (NSString *)originalPath;
- (void)setOriginalPath:(NSString *)value;

- (KTMediaStorageType)storageType;
- (void)setStorageType:(KTMediaStorageType)value;

- (NSString *)thumbnailUTI;
- (void)setThumbnailUTI:(NSString *)value;

- (NSDictionary *)metadata;
- (void)setMetadata:(NSDictionary *)value;

- (NSString *)uniqueID;

#pragma mark -
#pragma mark core data to-one relationships

/*	These 3 should be defunct in 1.5. File attributes are stored on disk
- (KTStoredDictionary *)fileAttributes;
- (void)setFileAttributes:(KTStoredDictionary *)value;
- (void)setFileAttributesFromDictionary:(NSDictionary *)aDictionary;
*/

- (KTManagedObject *)mediaData;
- (void)setMediaData:(KTManagedObject *)value;

- (KTManagedObject *)thumbnailData;
- (void)setThumbnailData:(KTManagedObject *)value;

#pragma mark image support

/*! returns NSImage from original (size) data */
- (NSImage *)imageConvertedFromData;
- (NSImage *)imageConvertedFromDataOfThumbSize:(int)aMaxSize;

/*! returns NSSize of image representation of original */
- (NSSize)imageSize;

/*! returns cached, normalized NSImage for inpector binding purposes */
- (NSImage *)bindableInspectorImage;

/*! returns TIFFRepresentation of bindableInspectorImage */
- (NSData *)TIFFRepresentation;

- (CIScalingBehavior)scalingBehaviorForKey:(NSString *)aKey;
- (NSImageAlignment)imageAlignmentForKey:(NSString *)aKey;

- (id)valueForUndefinedKey:(NSString *)aKey;

+ (BOOL)shouldConvertOriginalWithUTI:(NSString *)aUTI;

@end


@interface KTMedia ( ScaledImages )

/*! returns all CachedImages belonging to this media object */
- (NSArray *)allCachedImages;

/*! returns CachedImage where 'imageName like anImageName' */
- (KTCachedImage *)cachedImageForImageName:(NSString *)anImageName;

/*! returns image data for anImageName (should already be in preferred format) */
- (NSData *)dataForImageName:(NSString *)anImageName;

/*! returns whether object has pre-existing CachedImage named anImageName */
- (BOOL)hasCachedImageForImageName:(NSString *)anImageName;

/*! returns KTCachedImage or NSImage corresponding to anImageName */
- (id)imageForImageName:(NSString *)anImageName;

- (NSString *)imageNameForTag:(NSString *)aTag;


/*! returns MIME type corresponding to CachedImage's UTI */
- (NSString *)MIMETypeForImageName:(NSString *)anImageName;

/*! returns CachedImage marked as substituteOriginal */
- (KTCachedImage *)originalAsImage;

/*! removes all on-disk cache files */
- (BOOL)removeAllCacheFiles;

/*! removes all cache info for anImageName */
- (void)removeImageForImageName:(NSString *)anImageName;

- (NSMutableSet *)substitutableImageNames;
- (void)setSubstitutableImageNames:(NSMutableSet *)aSubstitutableImageNames;

- (BOOL)substituteOriginalForImageName:(NSString *)anImageName;

- (BOOL)hasValidCacheForImageName:(NSString *)anImageName;

@end

