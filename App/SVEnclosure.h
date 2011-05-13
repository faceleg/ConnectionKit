//
//  SVEnclosure.h
//  Sandvox
//
//  Created by Mike on 07/09/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class SVMedia, SVHTMLContext;


@protocol SVEnclosure
- (NSURL *)downloadedURL;   // where it currently resides on disk
- (long long)length;
- (NSURL *)addToContext:(SVHTMLContext *)context;
- (NSString *)MIMEType;
@end
