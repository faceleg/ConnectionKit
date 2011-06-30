//
//  SVImageRecipe.h
//  Sandvox
//
//  Created by Mike on 30/06/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SVImageRecipe : NSObject <NSCopying>
{
  @private
    NSData          *_sourceDigest;
    NSDictionary    *_parameters;
}

- (id)initWithSHA1DigestOfSourceMedia:(NSData *)sourceDigest parameters:(NSDictionary *)parameters;

@property(nonatomic, copy, readonly) NSData *SHA1DigestOfSourceMedia;
@property(nonatomic, copy, readonly) NSDictionary *parameters;

- (id)initWithContentHash:(NSData *)hash;
- (NSData *)contentHash;

@end
