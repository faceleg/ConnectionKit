//
//  KTWebView.h
//  Marvel
//
//  Created by Dan Wood on 8/11/04.
//  Copyright 2004-2009 Karelia Software. All rights reserved.
//

#import <WebKit/WebKit.h>

@interface KTWebView : WebView {
	BOOL myWindowIsMain;
	BOOL myWindowWasMainBeforeClick;
}

- (void)singleClickAtCoordinates:(NSPoint)aPoint modifierFlags:(unsigned int)modifierFlags;
- (void)doubleClickAtCoordinates:(NSPoint)aPoint modifierFlags:(unsigned int)modifierFlags;

- (BOOL)earlySingleClickAtCoordinates:(NSPoint)aPoint modifierFlags:(unsigned int)modifierFlags;
- (BOOL)earlyDoubleClickAtCoordinates:(NSPoint)aPoint modifierFlags:(unsigned int)modifierFlags;

@end

@interface NSObject ( KTWebViewAdditions )

- (void)webView:(WebView *)sender singleClickAtCoordinates:(NSPoint)aPoint modifierFlags:(unsigned int)modifierFlags;
- (void)webView:(WebView *)sender doubleClickAtCoordinates:(NSPoint)aPoint modifierFlags:(unsigned int)modifierFlags;

- (BOOL)webView:(WebView *)sender earlySingleClickAtCoordinates:(NSPoint)aPoint modifierFlags:(unsigned int)modifierFlags;
- (BOOL)webView:(WebView *)sender earlyDoubleClickAtCoordinates:(NSPoint)aPoint modifierFlags:(unsigned int)modifierFlags;

@end
