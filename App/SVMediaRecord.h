//
//  SVMedia.h
//  Sandvox
//
//  Created by Mike on 23/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "SVMediaProtocol.h"
#import "SVDocumentFileWrapper.h"


extern NSString *kSVDidDeleteMediaRecordNotification;


@class BDAlias;


@interface SVMediaRecord : NSManagedObject <SVMedia, SVDocumentFileWrapper>
{
  @private
    // Updating Files
    NSURL   *_destinationURL;
    BOOL    _moveWhenSaved;
    
    // Accessing Files
    NSURL           *_URL;
    NSURLResponse   *_URLResponse;
    NSDictionary    *_attributes;
    NSData          *_data;
    
    // Matching Media
    id <SVDocumentFileWrapper>  _nextObject;
}


#pragma mark Creating New Media

// Will return nil if an alias can't be created from the URL. It's OK if the file attributes can't be read in.
+ (SVMediaRecord *)mediaWithURL:(NSURL *)URL
                     entityName:(NSString *)entityName
 insertIntoManagedObjectContext:(NSManagedObjectContext *)context
                          error:(NSError **)outError;

// Must call -setPreferredFilename: after, and ideally -setFileAttributes: too
+ (SVMediaRecord *)mediaWithFileContents:(NSData *)data
                             URLResponse:(NSURLResponse *)response
                              entityName:(NSString *)entityName
          insertIntoManagedObjectContext:(NSManagedObjectContext *)context;

+ (SVMediaRecord *)mediaWithWebResource:(WebResource *)resource
                             entityName:(NSString *)entityName
         insertIntoManagedObjectContext:(NSManagedObjectContext *)context;


#pragma mark Updating Media Records

- (BOOL)moveToURL:(NSURL *)URL error:(NSError **)error;

// The document will order media about the place as part of its saving routines. No other code should call these directly.
// When removing a file from the package, it's because all corresponding Media Records are being deleted.
// One of them is placed in charge of making the move with a -moveToURLWhenDeleted: call
// If there are any other records referring to the same file, they follow along using the simpler -willMoveToURLWhenDeleted:
// In either case, it is implicit that, should the media be re-inserted due to an undo operation, the action will be reversed.
// It doesn't make sense to call either method for media that has never been committed to the store; trying to will raise an exception

- (void)moveToURLWhenDeleted:(NSURL *)URL;
- (void)willMoveToURLWhenDeleted:(NSURL *)URL;


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

- (NSURL *)fileURL;


#pragma mark Updating File Wrappers

// For now: options is ignored, always returns YES
- (BOOL)readFromURL:(NSURL *)URL options:(NSUInteger)options error:(NSError **)error;


#pragma mark Accessing Files

@property(nonatomic, copy) NSString *filename;  // no-one but the document should have reason to set this
@property(nonatomic, copy) NSString *preferredFilename;
@property(nonatomic, copy) NSDictionary *fileAttributes; // mostly to act as a cache

- (NSData *)fileContents;   // could return nil if the file is too big, or a directory
- (WebResource *)webResource;
- (BOOL)areContentsCached;
- (NSURLResponse *)fileURLResponse; // for in-memory media


#pragma mark Comparing Files

// Used to be -matchesContentsOfURL: but actually behaves rather differently to NSFileWrapper method of same name
- (BOOL)fileContentsEqualContentsOfURL:(NSURL *)url;
- (BOOL)fileContentsEqualData:(NSData *)data;


#pragma mark Location Support

// Media Files start out life with no filename. They acquire one upon the first time they are due to be copied into the doc package

@property(nonatomic, retain, readonly) BDAlias *alias;
@property(nonatomic, copy) NSNumber *shouldCopyFileIntoDocument;


#pragma mark Writing Files
- (BOOL)writeToURL:(NSURL *)URL updateFileURL:(BOOL)updateFileURL error:(NSError **)outError;


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

