//
//  SVMediaProtocol.h
//  Sandvox
//
//  Created by Mike on 22/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol SVMedia <NSObject>

- (NSURL *)fileURL;
- (NSData *)fileContents;

- (NSString *)filename; // non-nil value means the media should be inside the doc package (or deleted)
- (NSString *)preferredFilename;    // what the media would like to named given the chance

@end
