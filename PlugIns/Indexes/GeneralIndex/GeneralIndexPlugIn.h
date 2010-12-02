//
//  GeneralIndex.h
//  GeneralIndex
//
//  Copyright 2004-2010 Karelia Software. All rights reserved.
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
//  Community Note: This code is distrubuted under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//

#import "Sandvox.h"

typedef enum { kLayoutSections, kLayoutList, kLayoutTable } IndexLayoutType;

#define kCharsPerWord 5
#define kWordsPerSentence 10
#define kSentencesPerParagraph 5
#define kMaxTruncationParagraphs 20
// 5 * 10 * 5 * 20 = 5000 characters in 20 paragraphs, so this is our range

	
@interface GeneralIndexPlugIn : SVIndexPlugIn 
{
	BOOL _includeLargeMedia;
	BOOL _showThumbnails;
	BOOL _showTimestamps;
	IndexLayoutType _layoutType;
    BOOL _hyperlinkTitles;
    BOOL _shortTitles;
    BOOL _showPermaLinks;
    BOOL _showEntries;
    BOOL _showTitles;
    BOOL _showComments;
	BOOL _truncate;
	SVIndexTruncationType _truncationType;
    NSUInteger _truncateCount;
}

@property  BOOL hyperlinkTitles;
@property  BOOL includeLargeMedia;
@property  BOOL shortTitles;
@property  BOOL showPermaLinks;
@property  BOOL showEntries;
@property  BOOL showTitles;
@property  BOOL showThumbnails;
@property  BOOL showTimestamps;
@property  BOOL showComments;
@property  BOOL truncate;
@property  IndexLayoutType layoutType;
@property  SVIndexTruncationType truncationType;
@property  NSUInteger truncateCount;


+ (NSUInteger) truncationCountFromChars:(NSUInteger)chars forType:(SVIndexTruncationType)truncType;
+ (NSUInteger) charsFromTruncationCount:(NSUInteger)count forType:(SVIndexTruncationType)truncType;

@end
