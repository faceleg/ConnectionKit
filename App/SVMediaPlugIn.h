//
//  SVMediaPlugIn.h
//  Sandvox
//
//  Created by Mike on 24/09/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

//  Takes the public SVPlugIn API and extends for our private use for media-specific handling. Like a regular plug-in, still hosted by a Graphic object (Core Data modelled), but have full access to it via the -container method. Several convenience methods are provided so you don't have to call -container so much (-media, -externalSourceURL, etc.).


#import "SVPlugIn.h"
#import "SVEnclosure.h"

#import "SVMediaRecord.h"
#import "SVPlugInGraphic.h"


@interface SVMediaPlugIn : SVPlugIn <SVEnclosure>

#pragma mark Source
@property(nonatomic, readonly) SVMedia *media;  // KVO-compliant and everything!
- (NSURL *)externalSourceURL;
- (void)didSetSource;
+ (NSArray *)allowedFileTypes;  // subclasses should override

@property(nonatomic, readonly) SVMediaRecord *posterFrame;  // KVO-compliant
- (BOOL)validatePosterFrame:(SVMediaRecord *)posterFrame;
- (void)setPosterFrameWithMedia:(SVMedia *)media;   // nil removes poster frame


#pragma mark Publishing
@property(nonatomic, copy) NSString *typeToPublish; // KVO-compliant
- (BOOL)validateTypeToPublish:(NSString *)type;


#pragma mark Metrics

- (BOOL)validateHeight:(NSNumber **)height error:(NSError **)error;

// Please use this API rather than talking to the container
- (NSNumber *)naturalWidth;
- (NSNumber *)naturalHeight;
- (void)setNaturalWidth:(NSNumber *)width height:(NSNumber *)height;

// Implement this to fetch the media's natural size and call -setNaturalWidth:height: with it. Default implementation sets both dimensions to nil. -makeOriginalSize calls through to this method if a suitable natural size has not been set yet.
- (void)resetNaturalSize;


#pragma mark HTML

- (BOOL)canWriteHTMLInline;   // NO for most graphics. Images and Raw HTML return YES

// For backwards compat. with 1.x:
+ (NSString *)elementClassName; // e.g. "VideoElement"
+ (NSString *)contentClassName; // e.g. "photo"


#pragma mark Thumbnail
- (id <SVMedia>)thumbnailMedia;			// usually just media; might be poster frame of movie
- (id)imageRepresentation;
- (NSString *)imageRepresentationType;


#pragma mark Pasteboard
// Overrides inherited behaviour to return Web Location types plus +allowedFileTypes. You shouldn't need to customise any further.
+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard;


@end


@interface SVMediaPlugIn (Inherited)
@property(nonatomic, readonly) SVPlugInGraphic *container;
@end
