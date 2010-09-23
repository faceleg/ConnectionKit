//
//  SVImage.h
//  Sandvox
//
//  Created by Mike on 27/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//


#import "SVPlugIn.h"


@class SVLink, SVTextAttachment, SVMediaRecord;

@interface SVImage : SVPlugIn

+ (SVImage *)insertNewImageWithMedia:(SVMediaRecord *)media;


#pragma mark Special
@property(nonatomic, copy) NSString *alternateText;


#pragma mark Link
@property(nonatomic, copy) SVLink *link;


#pragma mark Publishing

@property(nonatomic) NSBitmapImageFileType storageType;
@property(nonatomic, copy) NSString *typeToPublish;

@property(nonatomic, copy) NSNumber *compressionFactor; // float, 0-1


@end



