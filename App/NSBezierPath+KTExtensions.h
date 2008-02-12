//
//  NSBezierPath+KTExtensions.h
//  Marvel
//
//  Created by Dan Wood on 2/5/08.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSBezierPath ( KTExtensions )

+ (NSBezierPath*)bezierPathWithRoundRectInRect:(NSRect)aRect radius:(float)radius;

@end
