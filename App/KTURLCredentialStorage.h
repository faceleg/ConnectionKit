//
//  KTURLCredentialStorage.h
//  Marvel
//
//  Created by Mike on 23/12/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


// A stand-in between CK and NSURLCredentialStorage that can handle SFTP


@interface KTURLCredentialStorage : NSObject 

+ (KTURLCredentialStorage *)sharedCredentialStorage;
- (NSURLCredential *)credentialForUser:(NSString *)user protectionSpace:(NSURLProtectionSpace *)space;
- (void)setCredential:(NSURLCredential *)credential forProtectionSpace:(NSURLProtectionSpace *)space;

@end
