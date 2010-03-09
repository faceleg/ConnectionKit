//
//  SVImage.h
//  Sandvox
//
//  Created by Mike on 27/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVIntroAndCaptionGraphic.h"


@class SVMediaRecord;
@class SVTextAttachment;


@interface SVImage : SVIntroAndCaptionGraphic

+ (SVImage *)insertNewImageWithMedia:(SVMediaRecord *)media;


@property (nonatomic, retain) SVMediaRecord *media;

@property(nonatomic, copy) NSNumber *width;
@property(nonatomic, copy) NSNumber *height;
@property(nonatomic, copy) NSNumber *constrainProportions;  // BOOL, required
- (CGSize)originalSize;


#pragma mark Link
@property(nonatomic, copy) NSString *linkURLString;


#pragma mark Publishing
@property(nonatomic, copy) NSNumber *storageType;  // NSBitmapImageFileType, mandatory
@property(nonatomic, copy) NSNumber *compressionFactor; // float, 0-1


@end



