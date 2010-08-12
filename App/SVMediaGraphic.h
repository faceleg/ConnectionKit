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
- (void)setMediaWithURL:(NSURL *)URL;

@property(nonatomic, copy) NSURL *externalSourceURL;

- (BOOL)hasFile;    // for bindings
- (NSURL *)sourceURL;


#pragma mark Metrics

@property(nonatomic, copy) NSNumber *contentWidth;
@property(nonatomic, copy) NSNumber *contentHeight;

// If -constrainProportions returns YES, sizing methods will adjust to maintain proportions
- (void)setSize:(NSSize)size;   // convenience

@property(nonatomic) BOOL constrainProportions;

- (CGSize)originalSize;
- (void)makeOriginalSize;
- (BOOL)canMakeOriginalSize;


@end
