//
//  HSAView.h
//  HostSetupAssistant
//
//  Created by Greg Hulands on 9/01/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface HSAView : NSBox
{
	NSColor *myBackgroundColor;
	NSColor *myBorderColor;
}

- (NSColor *)backgroundColor;
- (void)setBackgroundColor:(NSColor *)aBackgroundColor;
- (NSColor *)borderColor;
- (void)setBorderColor:(NSColor *)aBorderColor;

@end
