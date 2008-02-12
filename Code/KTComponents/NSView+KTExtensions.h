
/*
	NSView: Set and get a view's single subview
	Original Source: <http://cocoa.karelia.com/AppKit_Categories/NSView__Set_and_get.m>
	(See copyright notice at <http://cocoa.karelia.com>)
*/

#import <Cocoa/Cocoa.h>

@interface NSView ( KTExtensions )

- (NSImage *)snapshot;
- (NSImage *)snapshotFromRect:(NSRect)aRect;

- (void) setSubview:(NSView *)inView;
- (id) subview;

- (void)centerInRect:(NSRect)outerFrame;

@end
