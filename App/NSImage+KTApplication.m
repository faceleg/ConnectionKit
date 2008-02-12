//
//  NSImage+KTApplication.m
//  Marvel
//
//  Created by Dan Wood on 5/10/05.
//  Copyright (c) 2005 Biophony LLC. All rights reserved.
//

#import "NSImage+KTApplication.h"


@implementation NSImage ( KTApplication )

- (NSImage *)imageWithCompositedAddBadge
{
	static NSImage *sBadgeAddImage = nil;
	if (nil == sBadgeAddImage)
	{
		sBadgeAddImage = [[NSImage imageNamed:@"BadgeAdd"] retain];
	}
	

	NSImage *newImage = [[[NSImage alloc] initWithSize:[self size]] autorelease];
        
    [newImage lockFocus];
    [self drawAtPoint:NSZeroPoint
			 fromRect:NSMakeRect(0,0,[self size].width, [self size].height)
			operation:NSCompositeSourceOver fraction:1.0];

	[sBadgeAddImage drawAtPoint:NSZeroPoint
					   fromRect:NSMakeRect(0,0,[sBadgeAddImage size].width, [sBadgeAddImage size].height)
			operation:NSCompositeSourceOver fraction:1.0];
	
	[newImage unlockFocus];
	
	return newImage;
}

@end
