//
//  KTCachedImage.h
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

@class KTMedia, KTPage;

@interface KTCachedImage : KTManagedObject
{

}

#pragma mark public constructors

/*! returns CachedImage, creating image from aMediaObject and aName */
+ (KTCachedImage *)cachedImageWithImageName:(NSString *)aName
                                      media:(KTMedia *)aMediaObject;

/*! returns CachedImage that just points back to aMediaObject's data */
+ (KTCachedImage *)cachedImageSubstitutingOriginalForImageName:(NSString *)aName
                                                         media:(KTMedia *)aMediaObject;

#pragma mark operations

- (void)recacheInPreferredFormat;
- (void)recalculateSize;
- (BOOL)removeCacheFile;

#pragma mark accessors

/*! returns full file path to cache file */
- (NSString *)cacheAbsolutePath;

/*! returns name of cache file */
- (NSString *)cacheName;

/*! returns size (in bytes) of cache file */
- (NSNumber *)cacheSize;

/*! returns NSData with contents of cache file */
- (NSData *)data;

/*! returns partial sha1 digest of underlying data */
- (NSString *)digest;

/*! returns UTI of underlying data were it an NSImage */
- (NSString *)formatUTI;

/*! returns UTI of underlying data were it an NSImage,
	generating cache file if needed to determine UTI
*/
- (NSString *)formatUTICachingIfNecessary;

/*! returns YES if object has cache file on-disk, recaching if necessary */
- (BOOL)hasValidCacheFile;

/*! returns YES if object has cache file on-disk, does not recache */
- (BOOL)hasValidCacheFileNoRecache;

/*! returns underlying imageHeight, as a scalar */
- (unsigned int)height;

/*! returns associcated media relationship */
- (KTMedia *)media;

/*! returns underlying imageName */
- (NSString *)name;

/*! returns whether an NSImage created from the original media object
    should be substituted -- generally because the original would be
    the same size as what would be generated here
*/
- (BOOL)substituteOriginal;

/*! returns underlying imageWidth, as a scalar */
- (unsigned int)width;

#pragma mark NSImage support

/*! returns autoreleased NSImage created from cache in ~/Library/Caches/Sandvox */
- (NSImage *)image;

#pragma mark paths/URLs

- (NSString *)mediaPathRelativeTo:(KTPage *)aPage;
- (NSString *)publishedURL;

@end
