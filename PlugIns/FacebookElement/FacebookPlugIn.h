//
//  FacebookPlugIn.h
//  FacebookElement
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

/*
 The Like button lets a user share your content with friends on Facebook.
 When the user clicks the Like button on your site, a story appears in the 
 user's friends' News Feed with a link back to your website.
 <http://developers.facebook.com/docs/reference/plugins/like#>
 */

#import "Sandvox.h"

@interface FacebookPlugIn : SVPlugIn 
{
  @private
    BOOL _showFaces;
    NSUInteger _action;
    NSUInteger _colorscheme;
    NSUInteger _layout;
    NSUInteger _urlType;
    NSString *_urlString;
}

@property(nonatomic) BOOL showFaces;
@property(nonatomic) NSUInteger action;
@property(nonatomic) NSUInteger colorscheme;
@property(nonatomic) NSUInteger layout;
@property(nonatomic) NSUInteger urlType;
@property(nonatomic, retain) NSString *urlString;

@end
