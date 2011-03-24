//
//  PageCounterPlugIn.h
//  PageCounterElement
//
//  Copyright 2006-2011 Karelia Software. All rights reserved.
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

enum { PC_INVISIBLE = 0, PC_TEXT = 1, PC_GRAPHICS = 2 };

extern NSString *PCTypeKey;
extern NSString *PCThemeKey;
extern NSString *PCWidthKey;
extern NSString *PCHeightKey;
extern NSString *PCImagesPathKey;
extern NSString *PCSampleImageKey;
extern NSString *PCFilenameKey;


@interface PageCounterPlugIn : SVPlugIn
{
    NSUInteger _selectedThemeIndex;
}

+ (NSArray *)themes;
+ (NSMutableDictionary *)themeImages;
+ (NSImage *)sampleImageForFilename:(NSString *)filename;
+ (NSNumber *)widthOfSampleImageForFilename:(NSString *)filename;
+ (NSNumber *)heightOfSampleImageForFilename:(NSString *)filename;



// index into themes array
@property (nonatomic) NSUInteger selectedThemeIndex;

// derived
@property (nonatomic, readonly) NSArray *themes;
@property (nonatomic, readonly) NSDictionary *selectedTheme;

@property (nonatomic, readonly) NSString *themeTitle;
@property (nonatomic, readonly) NSNumber *themeWidth;
@property (nonatomic, readonly) NSNumber *themeHeight;
@property (nonatomic, readonly) NSUInteger themeType;

@end
