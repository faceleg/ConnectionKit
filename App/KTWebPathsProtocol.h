//
//  KTWebPathsProtocol.h
//  Marvel
//
//  Created by Mike on 19/03/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol KTWebPaths

- (NSURL *)absoluteURL;
- (NSString *)pathRelativeToSite;

@end
