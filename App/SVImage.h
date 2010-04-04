//
//  SVImage.h
//  Sandvox
//
//  Created by Mike on 27/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVIntroAndCaptionGraphic.h"


@class SVMediaRecord, SVLink;
@class SVTextAttachment;


@interface SVImage : SVIntroAndCaptionGraphic

+ (SVImage *)insertNewImageWithMedia:(SVMediaRecord *)media;
+ (SVImage *)insertNewImageInManagedObjectContext:(NSManagedObjectContext *)context;

#pragma mark Media

@property(nonatomic, retain) SVMediaRecord *media;
- (void)setMediaWithURL:(NSURL *)URL;

@property(nonatomic, copy) NSURL *externalSourceURL;

- (NSURL *)imagePreviewURL; // picks out URL from media, sourceURL etc.
- (NSURL *)placeholderImageURL; // the fallback when no media or external source is chose


#pragma mark Metrics
@property(nonatomic, copy) NSString *alternateText;


#pragma mark Size
@property(nonatomic, copy)  NSNumber *width;
@property(nonatomic, copy)  NSNumber *height;
@property(nonatomic)        BOOL constrainProportions;
- (CGSize)originalSize;


#pragma mark Link
@property(nonatomic, copy) SVLink *link;


#pragma mark Publishing
@property(nonatomic, copy) NSNumber *storageType;  // NSBitmapImageFileType, mandatory
@property(nonatomic, copy) NSNumber *compressionFactor; // float, 0-1


@end



