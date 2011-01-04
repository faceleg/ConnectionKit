//
//  SVMedia.h
//  Sandvox
//
//  Created by Mike on 23/01/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "KSExtensibleManagedObject.h"
#import "SVDocumentFileWrapper.h"
#import <iMedia/iMedia.h>

#import "SVMedia.h"


extern NSString *kSVDidDeleteMediaRecordNotification;


@class BDAlias, SVMedia;


@interface SVMediaRecord : KSExtensibleManagedObject <SVDocumentFileWrapper>
{
  @private
    NSString    *_filename;
    
    // Accessing Files
    SVMedia         *_media;
    NSDictionary    *_attributes;
    
    // Matching Media
    id <SVDocumentFileWrapper>  _nextObject;
}


#pragma mark Creating a Media Record

// Will return nil if an alias can't be created from the URL. It's OK if the file attributes can't be read in.
+ (SVMediaRecord *)mediaByReferencingURL:(NSURL *)URL
                     entityName:(NSString *)entityName
 insertIntoManagedObjectContext:(NSManagedObjectContext *)context
                          error:(NSError **)outError;

+ (SVMediaRecord *)mediaRecordWithMedia:(SVMedia *)media
                             entityName:(NSString *)entityName
         insertIntoManagedObjectContext:(NSManagedObjectContext *)context;

// 'bundled' means the URL should be inside either the app or design bundle
+ (SVMediaRecord *)mediaWithBundledURL:(NSURL *)URL
                            entityName:(NSString *)entityName
        insertIntoManagedObjectContext:(NSManagedObjectContext *)context;


#pragma mark Updating Media Records

- (BOOL)moveToURL:(NSURL *)URL error:(NSError **)error;


#pragma mark Location

//  Sandvox needs to handle media across a pretty broad set of locations. A file could be:
//  A)  Outside the document, under the user's control, so referenced by an alias
//  B)  Inside the document package
//  C)  In a temporary location on disk, outside the doc package, having been deleted from the document
//  D)  In-memory
//
//  In general you should get hold of a file in the manner that best suits you.
//  -   If you prefer data, ask for that. If it fails, it may be that the data is too big to reasonably load into memory, so fallback to -fileURL.
//  -   If you prefer a real file, use -fileURL. If that fails because the file is not found, it might be in-memory, so fallback to that.
//  You should have no need under normal usage to call -setFileURL: yourself; the document takes care of that for you. Similarly there should be no need to call -alias directly yourself.
//  .fileURL is not KVO-compliant

- (BOOL)isPlaceholder;
- (BOOL)isEditableText;	// used by SVURLPreviewController and KTPageDetailsController


#pragma mark Updating File Wrappers

// For now: options is ignored, always returns YES
- (BOOL)readFromURL:(NSURL *)URL options:(NSUInteger)options error:(NSError **)error;


#pragma mark Accessing Files

@property(nonatomic, retain, readonly) SVMedia *media; // KVO-compliant (alias resolution is cached)

@property(nonatomic, copy) NSString *filename;  // no-one but the document should have reason to set this
@property(nonatomic, copy) NSString *preferredFilename;
@property(nonatomic, copy) NSDictionary *fileAttributes; // mostly to act as a cache

- (BOOL)areContentsCached;
- (NSString *)typeOfFile;


#pragma mark Location Support

// Media Records start out life with no filename. They acquire one upon the first time they are due to be copied into the doc package

@property(nonatomic, copy) NSNumber *shouldCopyFileIntoDocument;
@property(nonatomic, retain, readonly) BDAlias *alias;
@property(nonatomic, retain, readonly) BDAlias *autosaveAlias;  // set when saving doc for autosave


#pragma mark Writing Files
- (BOOL)writeToURL:(NSURL *)URL updateFileURL:(BOOL)updateFileURL error:(NSError **)outError;
- (void)willAutosave;


#pragma mark Matching Media
// Two media records can refer to the same file on disk. So that we can do this still presenting a single object to KTDocument, matching records are chained together in a singly linked list using .nextObject.
@property(nonatomic, retain) id <SVDocumentFileWrapper> nextObject;


@end


#pragma mark -


@interface NSObject (SVMediaRecord)
// Calls -setValue:forKeyPath: with the media, but first deletes any existing media.
// IMPORTANT: The existing media's delete rule MUST be "No Action" otherwise Core Data tries to apply the rule during undo/redo and screws up, setting the property to nil.
- (void)replaceMedia:(SVMediaRecord *)media forKeyPath:(NSString *)keyPath;
@end

