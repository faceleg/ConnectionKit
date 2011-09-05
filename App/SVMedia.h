//
//  SVMedia.h
//  Sandvox
//
//  Created by Mike on 27/08/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "SVMediaProtocol.h"


@interface SVMedia : NSObject <SVMedia, NSCoding>
{
  @private
    NSURL       *_URL;
    NSData      *_data;
    WebResource *_webResource;
    
    NSString    *_preferredFilename;
    
    NSUInteger  _hash;
}

- (id)initByReferencingURL:(NSURL *)fileURL;
- (id)initWithContentsOfURL:(NSURL *)URL error:(NSError **)outError;
- (id)initWithWebResource:(WebResource *)resource;
- (id)initWithData:(NSData *)data URL:(NSURL *)URL;

@property(nonatomic, copy, readonly) NSURL *fileURL;
@property(nonatomic, copy, readonly) NSData *mediaData;
@property(nonatomic, copy, readonly) NSURL *mediaURL;
@property(nonatomic, copy, readonly) WebResource *webResource;

@property(nonatomic, copy) NSString *preferredFilename;


#pragma mark Comparing Media
- (BOOL)fileContentsEqualMedia:(SVMedia *)otherMedia;
// Used to be -matchesContentsOfURL: but actually behaves rather differently to NSFileWrapper method of same name
- (BOOL)fileContentsEqualContentsOfURL:(NSURL *)url;
- (BOOL)fileContentsEqualData:(NSData *)data;


#pragma mark Writing Files
- (BOOL)writeToURL:(NSURL *)URL error:(NSError **)outError;


#pragma mark Hash
- (NSData *)SHA1Digest;


#pragma mark Serialization
- (id)initWithSerializedProperties:(id)properties;
- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList;


@end
