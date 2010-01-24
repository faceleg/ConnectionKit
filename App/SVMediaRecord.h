//
//  SVMedia.h
//  Sandvox
//
//  Created by Mike on 23/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "SVMediaProtocol.h"


extern NSString *kSVDidDeleteMediaRecordNotification;


@class BDAlias;


@interface SVMediaRecord : NSManagedObject <SVMedia>
{
  @private
    // Updating Files
    NSURL   *_destinationURL;
    BOOL    _moveWhenSaved;
    
    // Accessing Files
    NSURL           *_URL;
    NSDictionary    *_attributes;
    NSData          *_data;
}


#pragma mark Creating New Media

// Will return nil if the URL can't be read
+ (SVMediaRecord *)mediaWithURL:(NSURL *)URL
                     entityName:(NSString *)entityName
 insertIntoManagedObjectContext:(NSManagedObjectContext *)context
                          error:(NSError **)outError;

// Must call -setPreferredFilename: after, and ideally -setFileAttributes: too
+ (SVMediaRecord *)mediaWithContents:(NSData *)data
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
//  You should have no need under normal usage to specifically use -alias.

- (NSURL *)fileURL;


#pragma mark Accessing Files

@property(nonatomic, copy) NSString *filename;  // no-one but the document should have reason to set this
@property(nonatomic, copy) NSString *preferredFilename;
@property(nonatomic, copy) NSDictionary *fileAttributes; // mostly to act as a cache

- (NSData *)fileContents;   // could return nil if the file is too big, or a directory
- (BOOL)areContentsCached;


#pragma mark Location Support

// Media Files start out life with no filename. They acquire one upon the first time they are due to be copied into the doc package

@property(nonatomic, retain, readonly) BDAlias *alias;
@property(nonatomic, copy) NSNumber *shouldCopyFileIntoDocument;


#pragma mark Writing Files
- (BOOL)writeToURL:(NSURL *)URL updateFileURL:(BOOL)updateFileURL error:(NSError **)outError;


@end
