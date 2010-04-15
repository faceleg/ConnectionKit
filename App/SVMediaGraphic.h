//
//  SVMediaGraphic.h
//  Sandvox
//
//  Created by Mike on 04/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVIntroAndCaptionGraphic.h"


@class SVMediaRecord;

@interface SVMediaGraphic : SVIntroAndCaptionGraphic

#pragma mark Media

@property(nonatomic, retain) SVMediaRecord *media;
- (void)setMediaWithURL:(NSURL *)URL;

@property(nonatomic, copy) NSURL *externalSourceURL;

- (NSURL *)imagePreviewURL; // picks out URL from media, sourceURL etc.
- (NSURL *)placeholderImageURL; // the fallback when no media or external source is chose


#pragma mark Size
@property(nonatomic, copy)  NSNumber *width;
@property(nonatomic, copy)  NSNumber *height;
@property(nonatomic)        BOOL constrainProportions;
- (CGSize)originalSize;
- (void)makeOriginalSize;


@end
