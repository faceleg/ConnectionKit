//
//  SVMediaGraphic.h
//  Sandvox
//
//  Created by Mike on 04/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVPlugInGraphic.h"


@class SVMediaRecord, SVMediaPlugIn;


@interface SVMediaGraphic : SVPlugInGraphic

#pragma mark Init
+ (id)insertNewGraphicInManagedObjectContext:(NSManagedObjectContext *)context;


#pragma mark Plug-In
- (SVMediaPlugIn *)plugIn;


#pragma mark Media

@property(nonatomic, retain) SVMediaRecord *media;
@property(nonatomic, copy) NSNumber *isMediaPlaceholder; // BOOL, mandatory
- (void)setMediaWithURL:(NSURL *)URL;

@property(nonatomic, copy) NSURL *externalSourceURL;

- (BOOL)hasFile;    // for bindings
- (NSURL *)sourceURL;

+ (BOOL)acceptsType:(NSString *)uti;
+ (NSArray *)allowedFileTypes;


#pragma mark Metrics


// If -constrainProportions returns YES, sizing methods will adjust to maintain proportions
- (void)setSize:(NSSize)size;   // convenience

@property(nonatomic) BOOL constrainProportions;
@property(nonatomic, copy, readonly) NSNumber *constrainedAspectRatio;

@property(nonatomic, copy) NSNumber *naturalWidth;		// Nil means unknown; 0 means checked but not attainable
@property(nonatomic, copy) NSNumber *naturalHeight;

- (CGSize)originalSize;

@end
