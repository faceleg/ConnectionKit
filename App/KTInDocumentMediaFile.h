//
//  KTInDocumentMediaFile.h
//  Marvel
//
//  Created by Mike on 28/09/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTMediaFile.h"


@class BDAlias;


@interface KTInDocumentMediaFile : KTMediaFile

@property(nonatomic, copy) NSString *preferredFilename;

+ (NSData *)mediaFileDigestFromData:(NSData *)data;
+ (NSData *)mediaFileDigestFromContentsOfFile:(NSString *)path;
@property(nonatomic, copy) NSData *cachedDigest;

@end
