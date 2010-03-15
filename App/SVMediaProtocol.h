//
//  SVMediaProtocol.h
//  Sandvox
//
//  Created by Mike on 22/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

//#import <Cocoa/Cocoa.h>
#import <iMedia/IMBImageItem.h>


@protocol SVMedia <NSObject, IMBImageItem>

- (NSURL *)fileURL;
- (NSData *)fileContents;

- (NSString *)filename; // non-nil value means the media should be inside the doc package (or deleted)
- (NSString *)preferredFilename;    // what the media would like to named given the chance

@end
