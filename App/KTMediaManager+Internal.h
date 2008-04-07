//
//  KTMediaManager+Internal.h
//  Marvel
//
//  Created by Mike on 23/12/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTMediaManager.h"

#import "KTInDocumentMediaFile.h"
#import "KTExternalMediaFile.h"


@class KTDesign, KTGraphicalTextMediaContainer;


@interface KTMediaManager (Internal)

// designated initializer
- (id)initWithDocument:(KTDocument *)document;



// Queries
- (NSSet *)temporaryMediaFiles;
- (NSString *)uniqueInDocumentFilename:(NSString *)preferredFilename;

- (NSArray *)inDocumentMediaFilesWithDigest:(NSString *)digest;
- (KTInDocumentMediaFile *)anyInDocumentMediaFileEqualToFile:(NSString *)path;


// Missing media
- (NSSet *)missingMediaFiles;


// Graphical Text
- (KTGraphicalTextMediaContainer *)graphicalTextWithString:(NSString *)string
													design:(KTDesign *)design
									  imageReplacementCode:(NSString *)imageReplacementCode
													  size:(float)size;

@end


@interface KTMediaManager (DocumentSaving)

// Tidying up
- (void)resetMediaFileStorage;
- (void)moveExternalMediaFileIntoDocument:(KTExternalMediaFile *)mediaFile;

- (void)garbageCollect;

- (void)deleteTemporaryMediaFiles;	// ONLY call when closing the doc

@end


/*	At the lowest level of the system is raw KTMediaFile management. Media Files are simple objects that
 *	represent a single unique piece of media, internal or external to the document. Code outside the media
 *	system should never have to manage KTMediaFile objects directly; the higher-level APIs do that.
 */
@interface KTMediaManager (MediaFiles)

// Queries
- (NSArray *)externalMediaFiles;

// MediaFile creation/re-use
- (KTMediaFile *)mediaFileWithPath:(NSString *)path;
- (KTMediaFile *)mediaFileWithPath:(NSString *)path preferExternalFile:(BOOL)preferExternal;
- (KTInDocumentMediaFile *)mediaFileWithData:(NSData *)data preferredFilename:(NSString *)filename;
- (KTInDocumentMediaFile *)mediaFileWithImage:(NSImage *)image;
- (KTMediaFile *)mediaFileWithDraggingInfo:(id <NSDraggingInfo>)info preferExternalFile:(BOOL)preferExternal;

- (BOOL)prepareTemporaryMediaDirectoryForFileNamed:(NSString *)filename;

@end

