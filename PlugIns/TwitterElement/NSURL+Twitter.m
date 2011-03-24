//
//  NSURL+Twitter.h
//  TwitterElement
//
//  Copyright (c) 2008-2011 Karelia Software. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  *  Redistribution of source code must retain the above copyright notice,
//     this list of conditions and the follow disclaimer.
//
//  *  Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other material provided with the distribution.
//
//  *  Neither the name of Karelia Software nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
//  Community Note: This code is distributed under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//

#import "NSURL+Twitter.h"


@implementation NSURL (Twitter)

// http://twitter.com/karelia
// http://twitter.com/#!/karelia
// http://twitter.com/karelia#

- (NSString *)twitterUsername
{
    NSString *result = nil;
    
    if ([[self host] isEqualToString:@"twitter.com"])
    {
        // the funky chars in twitter paths mess with NSURL, so we need to brute force this a bit
        NSString *URLAsString = [self absoluteString];
        NSRange range = [URLAsString rangeOfString:[self host]];
        NSString *twitterPath = [URLAsString substringFromIndex:range.location+range.length];
        
        if ( twitterPath )
        {
            NSCharacterSet *unwanted = [NSCharacterSet characterSetWithCharactersInString:@"#!/"];
            result = [twitterPath stringByTrimmingCharactersInSet:unwanted];
        }
    }
    
    return result;
}

@end
