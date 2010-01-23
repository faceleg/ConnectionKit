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

#import "SVMedia.h"


@class KTMediaManager, KTPage, BDAlias, KTMediaFileUpload;


@interface KTMediaFile : SVMedia

#pragma mark Media Manager
- (KTMediaManager *)mediaManager;


#pragma mark Location
- (NSString *)currentPath;	// just like -fileURL, but will never return nil. Falls back to a placeholder image instead


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
