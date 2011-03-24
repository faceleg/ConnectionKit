//
//  TweetButtonPlugIn.h
//  TweetButtonElement
//
//  Copyright (c) 2011 Karelia Software. All rights reserved.
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

#import <Sandvox.h>

/*
    Add this button to your website to let people share content on Twitter without having to leave the page. 
    Promote strategic Twitter accounts at the same time while driving traffic to your website.
    <http://twitter.com/goodies/tweetbutton>
 
    Additional dev options: <http://dev.twitter.com/pages/tweet_button>
 */
 
enum TweetButtonStyles { STYLE_VERTICAL, STYLE_HORIZONTAL, STYLE_NONE };

@interface TweetButtonPlugIn : SVPlugIn
{
    NSUInteger _tweetButtonStyle;
    NSString *_tweetText;
    NSString *_tweetURL;
    NSString *_tweetVia;
    NSString *_tweetRelated1;
    NSString *_tweetRelated2;
}

@property (nonatomic, readonly) NSString *tweetButton;
@property (nonatomic, readonly) NSString *tweetRelated;

@property (nonatomic) NSUInteger tweetButtonStyle;
@property (nonatomic, copy) NSString *tweetText;
@property (nonatomic, copy) NSString *tweetURL;
@property (nonatomic, copy) NSString *tweetVia;
@property (nonatomic, copy) NSString *tweetRelated1;
@property (nonatomic, copy) NSString *tweetRelated2;

@end
