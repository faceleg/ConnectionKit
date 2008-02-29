//
//  NSURL+KTExtensions.h
//  Marvel
//
//  Created by Dan Wood on 2/29/08.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSURL ( KTExtensions )

// Pasteboard
+ (NSArray *)KTComponentsSupportedURLPasteboardTypes;

+ (void)getURLs:(NSArray **)URLs
	  andTitles:(NSArray **)titles
 fromPasteboard:(NSPasteboard *)pasteboard;

+ (void)getURLs:(NSArray **)URLs
	  andTitles:(NSArray **)titles
 fromPasteboard:(NSPasteboard *)pasteboard
readWeblocFiles:(BOOL)convertWeblocs
 ignoreFileURLs:(BOOL)ignoreFileURLs;


@end
