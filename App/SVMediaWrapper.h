//
//  SVMedia.h
//  Sandvox
//
//  Created by Mike on 22/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

//  Somewhat like NSFileWrapper, but dedicated to Sandvox Media.
//  Key differences:
//      -   Provides you with a full file URL, not just filename
//      -   Will happily init with a file that no longer exists
//      -   Doesn't attempt to map files into memory
//      -   Allows KTDocument to perform its own unique filename generation


#import <Cocoa/Cocoa.h>


@class KTMediaFile, BDAlias;


@interface SVMediaWrapper : NSObject
{
  @private
    NSURL   *_fileURL;
    BDAlias *_alias;
    BOOL    _committed;
    
    KTMediaFile     *_mediaFile;
    
    NSString    *_preferredFilename;
    BOOL        _shouldCopyIntoDocument;
}

#pragma mark Creating Media Wrappers

// For new media, either:
//  -   init straight from a lump of data. Call -setPreferredFilename and -setFileAtrributes: after please
//  -   init from a URL, which the receiver will then track.
- (id)initWithURL:(NSURL *)URL;
- (id)initWithContents:(NSData *)contents;

// For existing media inside the document package (or that has been deleted)
- (id)initWithMediaFile:(KTMediaFile *)mediaFile;   // only supports committed media


#pragma mark Properties

@property(nonatomic, retain, readonly) KTMediaFile *mediaFile;


#pragma mark Accessing Files

- (NSURL *)fileURL; // wherever the file was last seen. Like -[NSFileWrapper filename] but beter
@property(nonatomic, copy) NSString *preferredFilename;
- (NSData *)fileContents;

@property(nonatomic, readonly) BOOL shouldCopyIntoDocument;
@property(nonatomic, readonly) BOOL hasBeenCopiedIntoDocument;


#pragma mark Writing Files
- (BOOL)writeToURL:(NSURL *)URL updateFileURL:(BOOL)updateFileURL error:(NSError **)outError;
   
   
@end
