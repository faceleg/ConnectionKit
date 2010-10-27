//
//  SVMediaPlugIn.h
//  Sandvox
//
//  Created by Mike on 24/09/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

//  Takes the public SVPlugIn API and extends for our private use for media-specific handling. Like a regular plug-in, still hosted by a Graphic object (Core Data modelled), but have full access to it via the -container method. Several convenience methods are provided so you don't have to call -container so much (-media, -externalSourceURL, etc.).


#import "SVPlugIn.h"
#import "SVEnclosure.h"

#import "SVMediaGraphic.h"


@interface SVMediaPlugIn : SVPlugIn <SVEnclosure>

#pragma mark Source
- (SVMediaRecord *)media;
- (NSURL *)externalSourceURL;
- (void)didSetSource;
+ (NSArray *)allowedFileTypes;

@property(nonatomic, readonly) SVMediaRecord *posterFrame;  // KVO-compliant
- (BOOL)validatePosterFrame:(SVMediaRecord *)posterFrame;
- (void)setPosterFrameWithContentsOfURL:(NSURL *)url;   // nil URL removes poster frame
- (void)setPosterFrameWithData:(NSData *)data URL:(NSURL *)url;


#pragma mark Publishing
- (BOOL)validateTypeToPublish:(NSString *)type;


#pragma mark Metrics

- (BOOL)validateHeight:(NSNumber **)height error:(NSError **)error;
- (BOOL)isConstrainProportionsEditable;

// Please use this API rather than talking to the container
- (NSNumber *)naturalWidth;
- (NSNumber *)naturalHeight;
- (void)setNaturalWidth:(NSNumber *)width height:(NSNumber *)height;
- (CGSize)originalSize;


#pragma mark HTML
- (BOOL)shouldWriteHTMLInline;
- (BOOL)canWriteHTMLInline;   // NO for most graphics. Images and Raw HTML return YES
- (id <SVMedia>)thumbnailMedia;			// usually just media; might be poster frame of movie
- (id)imageRepresentation;
- (NSString *)imageRepresentationType;


@end


@interface SVMediaPlugIn (Inherited)
@property(nonatomic, readonly) SVMediaGraphic *container;
@end
