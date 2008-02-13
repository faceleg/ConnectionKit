//
//  NSImage+KTApplication.h
//  Marvel
//
//  Created by Dan Wood on 5/10/05.
//  Copyright (c) 2005 Biophony LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSImage ( KTApplication )

- (NSImage *)imageWithCompositedAddBadge;

- (NSBitmapImageRep *)bitmapByScalingWithBehavior:(KTImageScalingSettings *)settings;

@end
