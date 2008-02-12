//
//  NSBundle+QuickLook.h
//  SandvoxQuickLook
//
//  Created by Dan Wood on 11/29/07.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSBundle ( QuickLook )

- (NSString *)version;				// specified as CFBundleShortVersionString
- (NSString *)minimumAppVersion;

@end
