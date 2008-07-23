//
//  KTMediaFile.h
//  Marvel
//
//  Created by Mike on 05/11/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
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

// Should be deprecated
+ (float)scaleFactorOfSize:(NSSize)sourceSize toFitSize:(NSSize)desiredSize;
+ (NSSize)sizeOfSize:(NSSize)sourceSize toFitSize:(NSSize)desiredSize;

// all return NSZeroSize if not an image
- (NSSize)dimensions;
- (void)cacheImageDimensions;

- (float)imageScaleFactorToFitSize:(NSSize)desiredSize;
- (NSSize)imageSizeToFitSize:(NSSize)desiredSize;
- (float)imageScaleFactorToFitWidth:(float)width;
- (float)imageScaleFactorToFitHeight:(float)height;

// Error Recovery
- (NSString *)bestExistingThumbnail;

@end
