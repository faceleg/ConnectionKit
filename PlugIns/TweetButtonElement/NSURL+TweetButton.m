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
    //FIXME: when self is "first-post.html -- //blog/", [self host] is blog rather than nil
    if ( ![self host] )
    {
        NSString *nohost = NSLocalizedString(@"«unspecified»", @"placeholder for site not yet set up for publishing.");
        return [nohost stringByAppendingPathComponent:[self path]];
    }
    else
    {
        return [self absoluteString];
    }
}

@end
