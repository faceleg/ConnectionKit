//
//  KTBackgroundTabView.h
//  Marvel
//
//  Created by Dan Wood on 11/16/04.
//  Copyright 2004-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface KTBackgroundTabView : NSTabView {

	NSColor *_backgroundColor;
	NSColor *_borderColor;
}

- (NSColor *)backgroundColor;
- (void)setBackgroundColor:(NSColor *)aBackgroundColor;
- (NSColor *)borderColor;
- (void)setBorderColor:(NSColor *)aBorderColor;

@end
