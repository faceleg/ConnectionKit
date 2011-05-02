//
//  SVMediaGraphic.h
//  Sandvox
//
//  Created by Mike on 04/04/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

//  For displaying media in the WebView an SVMediaGraphic is used. It takes SVPlugInGraphic but extends further by dynamically figuring the best .plugInIdentifier to match the current source and therefore create correct plug-in instance to match (from SVImage etc.). When changing source, a new plug-in is aytomatically swapped in if changing to a different media type.


#import "SVPlugInGraphic.h"
#import "SVMediaPlugIn.h"

@class SVMedia, SVMediaRecord;


@interface SVMediaGraphic : SVPlugInGraphic

#pragma mark Init
+ (id)insertNewGraphicInManagedObjectContext:(NSManagedObjectContext *)context;


#pragma mark Media

@property(nonatomic, retain, readonly) SVMediaRecord *media;
- (BOOL)hasFile;    // for bindings
- (void)setSourceWithMedia:(SVMedia *)media;
+ (NSString *)mediaEntityName;

@property(nonatomic, copy, readonly) NSURL *externalSourceURL;
- (void)setSourceWithExternalURL:(NSURL *)URL;

@property(nonatomic, retain) SVMediaRecord *posterFrame;

- (void)didSetSource;
- (NSURL *)sourceURL;

@property(nonatomic, copy) NSNumber *isMediaPlaceholder; // BOOL, mandatory

+ (BOOL)acceptsType:(NSString *)uti;
+ (NSArray *)allowedTypes;


#pragma mark Media Type
@property(nonatomic, copy) NSString *codecType;
@property(nonatomic, copy) NSString *typeToPublish;


#pragma mark Metrics

@property(nonatomic, copy, readonly) NSNumber *constrainedAspectRatio;

@property(nonatomic, copy) NSNumber *naturalWidth;		// Nil means unknown; 0 means checked but not attainable
@property(nonatomic, copy) NSNumber *naturalHeight;


#pragma mark PlugIn
- (void)reloadPlugInIfNeeded;


@end


@interface SVMediaGraphic (PlugIn)
- (SVMediaPlugIn *)plugIn;
@end

