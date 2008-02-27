//
//  KTCircularProgressCell.h
//  Marvel
//
//  Created by Greg Hulands on 10/01/06.
//  Copyright 2006 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface KTCircularProgressCell : NSCell
{
	NSColor *myColor;
	NSImage *myImage;
	NSImage *myWarningImage;
	NSNumber *myProgress;
}

- (void)setProgress:(NSNumber *)progress;
- (NSNumber *)progress;

- (void)setCompletedImage:(NSImage *)image;
- (NSImage *)completedImage;

- (void)setColor:(NSColor *)color;
- (NSColor *)color;

@end
