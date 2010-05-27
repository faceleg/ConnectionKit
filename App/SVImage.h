//
//  SVImage.h
//  Sandvox
//
//  Created by Mike on 27/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//


#import "SVMediaGraphic.h"


@class SVLink, SVTextAttachment;

@interface SVImage : SVMediaGraphic

+ (SVImage *)insertNewImageWithMedia:(SVMediaRecord *)media;
+ (SVImage *)insertNewImageInManagedObjectContext:(NSManagedObjectContext *)context;


#pragma mark File Info
@property(nonatomic, copy) NSURL *placeholderImageURL; // the fallback when no media or external source is chose


#pragma mark Metrics
@property(nonatomic, copy) NSString *alternateText;


#pragma mark Link
@property(nonatomic, copy) SVLink *link;


#pragma mark Publishing
@property(nonatomic, copy) NSNumber *storageType;  // NSBitmapImageFileType, mandatory
@property(nonatomic, copy) NSNumber *compressionFactor; // float, 0-1


@end



