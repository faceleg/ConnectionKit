// 
//  SVExternalLink.m
//  Sandvox
//
//  Created by Mike on 13/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVExternalLink.h"

#import "NSURL+Karelia.h"


@implementation SVExternalLink 

@dynamic openInNewWindow;
@dynamic linkURLString;

- (NSString *)fileName
{
    NSURL *URL = [NSURL URLWithString:[self linkURLString]];
    return [[URL lastPathComponent] stringByDeletingPathExtension];
}

@end
