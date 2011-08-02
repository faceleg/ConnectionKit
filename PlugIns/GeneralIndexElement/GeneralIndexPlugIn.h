//
//  GeneralIndex.h
//  GeneralIndex
//
//  Copyright 2004-2011 Karelia Software. All rights reserved.
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

#import "Sandvox.h"

enum {
	kArticleMask	= 1UL << 0,		// 1
	kTitleMask		= 1UL << 1,		// 2
	kListMask		= 1UL << 2,		// 4
	kTableMask		= 1UL << 3,		// 8
	kLargeMediaMask	= 1UL << 4,		// 16
	kThumbMask		= 1UL << 5,		// 32
	kFloatThumbMask	= 1UL << 6,		// 64
	kInsetThumbMask	= 1UL << 7,		// 128 Not implemented yet
	kLargeMediaIfBigEnough = 1UL << 8	// 256			// Not really using anymore, but keep so the masks don't change
};

// If these change, we need to change the tags on the popup menu in the nib.
typedef enum {
	kLayoutNone					= 0,
	kLayoutTitles				= kTitleMask,																// 2
	kLayoutTitlesList			= kTitleMask | kListMask,													// 6
	kLayoutTable				= kTitleMask | kArticleMask | kThumbMask		| kTableMask,				// 43
	kLayoutArticlesAndThumbs	= kTitleMask | kArticleMask | kThumbMask | kFloatThumbMask,					// 99
	kLayoutArticlesAndMedia		= kTitleMask | kArticleMask | kLargeMediaMask | kLargeMediaIfBigEnough,		// 275

} IndexLayoutType;
 	
@interface GeneralIndexPlugIn : SVIndexPlugIn 
{
	BOOL _showTimestamps;
    NSUInteger _timestampType;
	IndexLayoutType _indexLayoutType;
    BOOL _hyperlinkTitles;
    BOOL _richTextTitles;
    BOOL _showPermaLinks;
    BOOL _showEntries;			// transient only, for bindings
    BOOL _showTitles;			// transient only, for bindings
    BOOL _isTable;				// transient only, for bindings
    BOOL _showComments;
    BOOL _showArticleInTables;
    BOOL _showContinueReadingLink;
    NSUInteger _maxItemLength;
}

@property (nonatomic) BOOL hyperlinkTitles;
@property (nonatomic) BOOL richTextTitles;
@property (nonatomic) BOOL showPermaLinks;
@property (nonatomic) BOOL showEntries;
@property (nonatomic) BOOL showTitles;
@property (nonatomic) BOOL isTable;
@property (nonatomic) BOOL showTimestamps;
@property (nonatomic) BOOL showArticleInTables;
@property (nonatomic) BOOL showContinueReadingLink;
@property (nonatomic) NSUInteger timestampType;
@property (nonatomic) BOOL showComments;
@property (nonatomic) IndexLayoutType indexLayoutType;
@property (nonatomic) NSUInteger maxItemLength;



@end
