//
//  KTMediaManager+Internal.h
//  Marvel
//
//  Created by Mike on 23/12/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTMediaManager.h"


@class KTDesign, KTGraphicalTextMediaContainer;


@interface KTMediaManager (Internal)

// designated initializer
- (id)initWithDocument:(KTDocument *)document;



// Queries
- (NSArray *)externalMediaFiles;
- (NSSet *)temporaryMediaFiles;
- (NSString *)uniqueInDocumentFilename:(NSString *)preferredFilename;

- (NSArray *)inDocumentMediaFilesWithDigest:(NSString *)digest;
- (KTInDocumentMediaFile *)anyInDocumentMediaFileEqualToFile:(NSString *)path;


// Media file creation
- (KTAbstractMediaFile *)mediaFileWithPath:(NSString *)path;
- (KTAbstractMediaFile *)mediaFileWithPath:(NSString *)path preferExternalFile:(BOOL)preferExternal;
- (KTInDocumentMediaFile *)mediaFileWithData:(NSData *)data preferredFilename:(NSString *)filename;
- (KTInDocumentMediaFile *)mediaFileWithImage:(NSImage *)image;
- (KTAbstractMediaFile *)mediaFileWithDraggingInfo:(id <NSDraggingInfo>)info preferExternalFile:(BOOL)preferExternal;


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


