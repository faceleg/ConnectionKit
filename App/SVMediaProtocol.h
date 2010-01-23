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
@end
