//
//  SVMedia.h
//  Sandvox
//
//  Created by Mike on 22/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

//  Somewhat like NSFileWrapper, but dedicated to Sandvox Media.


#import <Cocoa/Cocoa.h>


@class KTMediaFile, KTDocument;


@interface SVMedia : NSObject
{
  @private
    KTMediaFile     *_mediaFile;
    KTDocument  *_document; // weak ref
    
    NSString    *_filename;
    NSString    *_preferredFilename;
}

- (id)initWithMediaFile:(KTMediaFile *)mediaFile;
@property(nonatomic, retain, readonly) KTMediaFile *mediaFile;

@property(nonatomic, copy) NSString *filename;
@property(nonatomic, copy) NSString *preferredFilename;

@property(nonatomic, assign) KTDocument *document;

@end
