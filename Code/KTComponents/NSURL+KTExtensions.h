//
//  NSURL+KTExtensions.h
//  KTComponents
//
//  Created by Mike on 05/01/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSURL (KTExtensions)

- (BOOL)hasNetworkLocation;

// Webloc files
+ (void)getURL:(NSURL **)URL andTitle:(NSString **)title fromWeblocFile:(NSString *)path;

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
