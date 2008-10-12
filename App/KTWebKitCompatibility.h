/*
 *  KTWebKitCompatibility.h
 *  Marvel
 *
 *  Created by Terrence Talbot on 2/13/08.
 *  Copyright 2008 Karelia Software. All rights reserved.
 *
 */

// this header provides "compatibility" between the stock 10.4 SDK which includes an older version of WebKit
// and the newer API that is used in 10.4.11 and 10.5.*

// this file should be removed when we no longer get missing WebKit API warnings in a Release build

#import <WebKit/WebKit.h>

@interface DOMCSSStyleDeclaration ( KTWebKitCompatibility )
- (void)setProperty:(NSString *)propertyName value:(NSString *)value priority:(NSString *)priority;
@end

@interface DOMElement ( KTWebKitCompatibility )
- (void)focus;
@end

@interface DOMNode ( KTWebKitCompatibility )
- (NSString *)textContent;
@end

@interface DOMRange ( KTWebKitCompatibility )
- (void)setStart:(DOMNode *)refNode offset:(int)offset;
- (void)setEnd:(DOMNode *)refNode offset:(int)offset;
@end

@interface WebView ( KTWebKitCompatibility )
- (DOMDocument *)mainFrameDocument;
- (BOOL)isLoading;
- (BOOL)canMakeTextStandardSize;
@end
