//
//  KTMediaManager+Internal.h
//  Marvel
//
//  Created by Mike on 23/12/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTMediaManager.h"

#import "KTMediaFile.h"


@class KTDesign;


@interface KTMediaManager (Internal)

// designated initializer
- (id)initWithDocument:(KTDocument *)document;



// Missing media
- (NSSet *)missingMediaFiles;


// Tidying up
- (void)moveApplicableExternalMediaInDocument;

- (void)garbageCollect;


@end

/*	At the lowest level of the system is raw KTMediaFile management. Media Files are simple objects that
 *	represent a single unique piece of media, internal or external to the document. Code outside the media
 *	system should never have to manage KTMediaFile objects directly; the higher-level APIs do that.
 */
@interface KTMediaManager (MediaFilesInternal)

// Queries
- (NSArray *)externalMediaFiles;
- (KTMediaFile *)mediaFileWithIdentifier:(NSString *)identifier;

// MediaFile creation/re-use
- (KTMediaFile *)mediaFileWithPath:(NSString *)path;
- (KTMediaFile *)mediaFileWithPath:(NSString *)path preferExternalFile:(BOOL)preferExternal;
- (KTMediaFile *)mediaFileWithData:(NSData *)data preferredFilename:(NSString *)filename;
- (KTMediaFile *)mediaFileWithImage:(NSImage *)image;
- (KTMediaFile *)mediaFileWithDraggingInfo:(id <NSDraggingInfo>)info preferExternalFile:(BOOL)preferExternal;

@end


