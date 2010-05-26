//
//  WEKWebKitPrivate.h
//  Sandvox
//
//  Created by Mike on 26/05/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

//  Just a simple declaration of some known WebKit private APIs we use.


#import <Cocoa/Cocoa.h>


// Copied out of WebKit, ScrollTypes.h
typedef enum {
    ScrollbarAuto,
    ScrollbarAlwaysOff,
    ScrollbarAlwaysOn
} ScrollbarMode;


@interface WebView (WEK_Private)
- (void)_setCatchesDelegateExceptions:(BOOL)flag;
@end


@interface NSScrollView (WEK_WebDynamicScrollBarsView)
- (void)setVerticalScrollingMode:(ScrollbarMode)verticalMode;
@end


@interface NSView (WEK_WebExtras)
- (BOOL)_web_dragShouldBeginFromMouseDown:(NSEvent *)mouseDownEvent
                           withExpiration:(NSDate *)expiration;
@end


