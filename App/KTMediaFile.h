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


@class KTMediaManager, KTPage, KTMediaFileUpload;
@interface KTMediaFile : NSManagedObject
{	
}

+ (NSString *)entityName;

// Accessors
- (KTMediaManager *)mediaManager;
- (NSString *)fileType;
- (NSString *)filename;
- (NSString *)filenameExtension;


// Paths
- (NSString *)currentPath;	// Where the file is currently being stored.
- (NSString *)_currentPath;
- (NSString *)quickLookPseudoTag;

- (KTMediaFileUpload *)defaultUpload;
- (KTMediaFileUpload *)uploadForPath:(NSString *)path;
- (NSString *)uniqueUploadPath:(NSString *)preferredPath;


// Should be deprecated
+ (float)scaleFactorOfSize:(NSSize)sourceSize toFitSize:(NSSize)desiredSize;
+ (NSSize)sizeOfSize:(NSSize)sourceSize toFitSize:(NSSize)desiredSize;

// all return NSZeroSize if not an image
- (NSSize)dimensions;
- (void)cacheImageDimensions;
- (void)cacheImageDimensionsIfNeeded;

- (float)imageScaleFactorToFitSize:(NSSize)desiredSize;
- (NSSize)imageSizeToFitSize:(NSSize)desiredSize;
- (float)imageScaleFactorToFitWidth:(float)width;
- (float)imageScaleFactorToFitHeight:(float)height;


// Error Recovery
- (NSString *)bestExistingThumbnail;

@end
