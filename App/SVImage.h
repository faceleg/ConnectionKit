//
//  SVImage.h
//  Sandvox
//
//  Created by Mike on 27/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "SVGraphic.h"

@class SVMediaRecord;
@class SVTextAttachment;

@interface SVImage : SVGraphic

+ (SVImage *)insertNewImageWithMedia:(SVMediaRecord *)media;


@property (nonatomic, retain) SVMediaRecord *media;

@property(nonatomic, copy) NSNumber *width;
@property(nonatomic, copy) NSNumber *height;
@property(nonatomic, copy) NSNumber *constrainProportions;  // BOOL, required
- (CGSize)originalSize;


#pragma mark Publishing
@property(nonatomic, copy) NSString *fileType;  // e.g. kUTTypePNG
@property(nonatomic, copy) NSNumber *compressionFactor; // float, 0-1


@end



