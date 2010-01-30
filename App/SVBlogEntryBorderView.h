//
//  SVBlogEntryBorderView.h
//  Sandvox
//
//  Created by Dan Wood on 1/29/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//
// Show the controls for a blog entry

#import <Cocoa/Cocoa.h>


@interface SVBlogEntryBorderView : NSObject 

- (NSRect)frameRectForGraphicBounds:(NSRect)frameRect;

- (void)drawWithFrame:(NSRect)frameRect inView:(NSView *)view;

- (void)drawWithGraphicBounds:(NSRect)frameRect inView:(NSView *)view;

- (NSRect)drawingRectForGraphicBounds:(NSRect)frameRect;	// called by client

@end
