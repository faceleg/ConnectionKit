//
//  NSURL+TweetButton.m
//  TweetButtonElement
//
//  Created by Terrence Talbot on 5/1/11.
//  Copyright 2011 Terrence Talbot. All rights reserved.
//

#import "NSURL+TweetButton.h"


@implementation NSURL (TweetButton)

- (NSString *)svx_placeholderString
{
    if ( ![self host] || ![self scheme] )
    {
        NSString *nohost = NSLocalizedString(@"«unspecified»", @"placeholder for site not yet set up for publishing.");
        return [nohost stringByAppendingPathComponent:[self relativePath]];
    }
    else
    {
        return [self absoluteString];
    }
}

@end
