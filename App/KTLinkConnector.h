//
//  KTLinkConnector.h
//  Marvel
//
//  Created by Greg Hulands on 19/03/06.
//  Copyright 2006-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface KTLinkConnector : NSWindow <NSDraggingInfo>
{
	NSView *lastViewOver;
	NSPoint lastPoint;
	NSPasteboard *pboard;
	NSDate *myStartTime;
}

+ (id)sharedConnector;

- (void)startConnectionWithPoint:(NSPoint)point pasteboard:(NSPasteboard *)pasteboard targetWindow:(NSWindow *)aWindow;
- (void)showConnectionWithFrame:(NSRect)frame;
- (void)endConnection;

@end
