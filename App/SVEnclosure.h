//
//  SVEnclosure.h
//  Sandvox
//
//  Created by Mike on 07/09/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol SVEnclosure
- (NSURL *)downloadedURL;   // where it currently resides on disk
- (long long)length;
- (NSString *)MIMEType;
- (NSURL *)URL;
@end
