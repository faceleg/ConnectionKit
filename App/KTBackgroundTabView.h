//
//  KTBackgroundTabView.h
//  Marvel
//
//  Created by Dan Wood on 11/16/04.
//  Copyright 2004 Biophony, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface KTBackgroundTabView : NSTabView {

	NSColor *myBackgroundColor;
	NSColor *myBorderColor;
}

- (NSColor *)backgroundColor;
- (void)setBackgroundColor:(NSColor *)aBackgroundColor;
- (NSColor *)borderColor;
- (void)setBorderColor:(NSColor *)aBorderColor;

@end
