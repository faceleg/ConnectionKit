//
//  YouTubeCocoaExtensions.h
//  YouTubeElement
//
//  Created by Mike on 08/04/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSString (YouTubeExtensions)
- (BOOL)isYouTubeVideoID;
@end


@interface NSURL (YouTubeExtensions)
- (NSString *)youTubeVideoID;
@end