//
//  SVMedia.h
//  Sandvox
//
//  Created by Mike on 23/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "SVMediaProtocol.h"


extern NSString *kSVMediaWantsCopyingIntoDocumentNotification;

@class BDAlias;


@interface SVMediaRecord : NSManagedObject <SVMedia>
{
  @private
    NSURL   *_URL;
    
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

@property(nonatomic, copy, readonly) NSString *filename;
@property(nonatomic, copy) NSString *preferredFilename;
@property(nonatomic, copy) NSDictionary *fileAttributes; // mostly to act as a cache

- (NSData *)fileContents;   // could return nil if the file is too big, or a directory
- (BOOL)areContentsCached;


#pragma mark Location Support

// Media Files start out life with no filename. They acquire one upon the first time they are due to be copied into the doc package

@property(nonatomic, retain, readonly) BDAlias *alias;
@property(nonatomic, copy) NSNumber *shouldCopyFileIntoDocument;


@end
