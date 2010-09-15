//
//  SVMediaGraphic.h
//  Sandvox
//
//  Created by Mike on 04/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVGraphic.h"


@class SVMediaRecord;

@interface SVMediaGraphic : SVGraphic

#pragma mark Media

@property(nonatomic, retain) SVMediaRecord *media;
@property(nonatomic, copy) NSNumber *isMediaPlaceholder; // BOOL, mandatory
- (void)setMediaWithURL:(NSURL *)URL;

@property(nonatomic, copy) NSURL *externalSourceURL;

- (BOOL)hasFile;    // for bindings
- (NSURL *)sourceURL;


#pragma mark Metrics


// If -constrainProportions returns YES, sizing methods will adjust to maintain proportions
- (void)setSize:(NSSize)size;   // convenience

@property(nonatomic) BOOL constrainProportions;
@property(nonatomic, copy, readonly) NSNumber *constrainedAspectRatio;

@property(nonatomic, copy) NSNumber *contentWidth;
@property(nonatomic, copy) NSNumber *contentHeight;
@property(nonatomic, copy) NSNumber *naturalWidth;		// Nil means unknown; 0 means checked but not attainable
@property(nonatomic, copy) NSNumber *naturalHeight;

- (CGSize)originalSize;
- (void)makeOriginalSize;
- (BOOL)canMakeOriginalSize;

@end
