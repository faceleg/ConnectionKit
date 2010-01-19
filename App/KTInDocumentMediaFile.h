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
+ (NSString *)mediaFileDigestFromData:(NSData *)data;
+ (NSString *)mediaFileDigestFromContentsOfFile:(NSString *)path;
- (NSString *)digest;

@property(nonatomic, copy) NSString *preferredFilename;

@end
