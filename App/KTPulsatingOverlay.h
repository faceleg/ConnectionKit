//
//  KTPulsatingOverlay.h
//  Marvel
//
//  Created by Greg Hulands on 23/03/06.
//  Copyright 2006-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface KTPulsatingOverlay : NSWindow 
{
	NSTimer *myAnimateTimer;
	int myAlpha;
	BOOL isFading;
}

+ (id)sharedOverlay;

- (void)displayWithFrame:(NSRect)frame;
- (void)hide;

@end
