//
//  SVWorkspaceIconProtocol.h
//  Sandvox
//
//  Created by Mike on 05/07/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SVWorkspaceIconProtocol : NSURLProtocol
{

}

+ (NSURL *)URLForWorkspaceIconOfURL:(NSURL *)fileURL;

@end
