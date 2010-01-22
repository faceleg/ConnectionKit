//
//  KTMediaFile.h
//  Sandvox
//
//  Copyright 2007-2009 Karelia Software. All rights reserved.
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

#import <Cocoa/Cocoa.h>
#import "SVMediaProtocol.h"


@class KTMediaManager, KTPage, BDAlias, KTMediaFileUpload;


@interface KTMediaFile : NSManagedObject <SVMedia>
{
  @private
    NSData  *_data;
}

#pragma mark Raw Init

- (id)initWithData:(NSData *)data preferredFilename:(NSString *)preferredFilename insertIntoManagedObjectContext:(NSManagedObjectContext *)moc;

// Uses an alias to track the file, and also loads it into memory if small enough
- (id)initWithURL:(NSURL *)URL insertIntoManagedObjectContext:(NSManagedObjectContext *)moc;


#pragma mark Media Manager
- (KTMediaManager *)mediaManager;


#pragma mark Location

//  Sandvox needs to handle media across a pretty broad set of locations. A file could be:
//  A)  Outside the document, under the user's control, so referenced by an alias
//  B)  Inside the document package
//  C)  In a temporary location on disk, outside the doc package, having been deleted from the document
//  D)  In-memory
//
//  In general you should get hold of a file in the manner that best suits you.
//  -   If you prefer data, ask for that. If it fails, it may be that the data is too big to reasonably load into memory, so fallback to -fileURL.
//  -   If you prefer a real file, use -fileURL. If that fails because the file is not found, it might be in-memory, so fallback to that.
//  You should have no need under normal usage to specifically use -alias.

- (NSURL *)fileURL;
- (NSString *)currentPath;	// just like -fileURL, but will never return nil. Falls back to a placeholder image instead


#pragma mark Contents Cache
- (NSData *)fileContents;   // could return nil if the file is too big, or a directory
- (NSDictionary *)fileAttributes;
- (BOOL)areContentsCached;


#pragma mark Location Support

// Media Files start out life with no filename. They acquire one upon the first time they are due to be copied into the doc package
@property(nonatomic, copy, readonly) NSString *filename;

@property(nonatomic, retain, readonly) BDAlias *alias;
@property(nonatomic, copy) NSNumber *shouldCopyFileIntoDocument;
@property(nonatomic, copy) NSString *preferredFilename;


#pragma mark Quick Look
- (NSString *)quickLookPseudoTag;


#pragma mark Publishing

- (KTMediaFileUpload *)defaultUpload;
- (KTMediaFileUpload *)uploadForPath:(NSString *)path;
- (KTMediaFileUpload *)uploadForScalingProperties:(NSDictionary *)scalingProps;

- (NSString *)uniqueUploadPath:(NSString *)preferredPath;


// Error Recovery
- (NSString *)bestExistingThumbnail;

@end


#pragma mark -


#import "KTPasteboardArchiving.h"
#import "CIImage+Karelia.h"


@class KTImageScalingSettings;


@interface KTMediaFile (Internal) <KTPasteboardArchiving>

+ (id)insertNewMediaFileWithPath:(NSString *)path inManagedObjectContext:(NSManagedObjectContext *)moc;

// Basically the same as -[NSFileWrapper preferredFilename]. It's designed for management of files within the package; not for upload purposes.
- (NSString *)preferredFilename;

// Scaling
- (NSURL *)URLForImageScaledToSize:(NSSize)size
							  mode:(KSImageScalingMode)scalingMode
						sharpening:(float)sharpening
						  fileType:(NSString *)UTI;
- (NSURL *)URLForImageScalingProperties:(NSDictionary *)properties;
- (NSURLRequest *)URLRequestForImageScalingProperties:(NSDictionary *)properties;

- (NSDictionary *)canonicalImageScalingPropertiesForProperties:(NSDictionary *)properties;
- (KTImageScalingSettings *)canonicalImageScalingSettingsForSettings:(KTImageScalingSettings *)settings;

@end
