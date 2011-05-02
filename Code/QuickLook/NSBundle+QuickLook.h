//
//  NSBundle+QuickLook.h
//  SandvoxQuickLook
//
//  Created by Dan Wood on 11/29/07.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSBundle (QuickLook)

+ (NSBundle *)quickLookBundleWithIdentifier:(NSString *)identifier;

- (NSString *)marketingVersion;				// specified as CFBundleShortVersionString
- (NSString *)minimumAppVersion;

- (NSString *)quicklookDataForFile:(NSString *)file;
@end
