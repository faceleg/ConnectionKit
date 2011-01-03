//
//  KTMagnifyButton.m
//  KTComponents
//
//  Created by Terrence Talbot on 1/18/05.
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//

#import "KTMagnifyButton.h"

#import "Debug.h"
#import "NSImage+Karelia.h"

@implementation KTMagnifyButton

- (id)initWithFrame:(NSRect)frameRect
{
	if ( self = [super initWithFrame:frameRect] )
	{
        ;
	}
    
	return self;
}

- (void)dealloc
{
	[myPopView release]; myPopView = nil;
	[myBorderlessWindow release]; myBorderlessWindow = nil;
    
	[super dealloc];
}

- (void)awakeFromNib
{
    NSImage *image = [NSImage imageInBundle:[NSBundle bundleForClass:[self class]] named:@"mag"];
    if ( nil != image )
    {
        [self setImage:image];
        [self setEnabled:YES];
    }
    else
    {
        LOG((@"unable to load image mag"));
    }
}

// change: click to show scaled image
// to add: option-click to see full size image
- (void)mouseDown:(NSEvent *)theEvent
{
	NSImage *image = [oSourceImageView image];
	if ( image != nil && [image size].width > 5.0 )
	{
		NSPoint mouseLocation = [theEvent locationInWindow];
		NSPoint newOrigin = [[theEvent window] convertBaseToScreen:mouseLocation];
        
		[myPopView release];
		[myBorderlessWindow release];
        
		myBorderlessWindow = [[NSWindow allocWithZone:[self zone]] initWithContentRect:[[self window] frame] styleMask:NSBorderlessWindowMask backing:NSBackingStoreNonretained defer:YES screen:[[self window] screen]];
		myPopView = [[NSImageView allocWithZone:[self zone]] initWithFrame:[[myBorderlessWindow contentView] frame]];
        
		[myBorderlessWindow setContentView:myPopView];
		[myBorderlessWindow setBackgroundColor:[NSColor whiteColor]];
        
		[myPopView setImage:image];
        
		[myBorderlessWindow setContentSize:[[myPopView image] size]];
		[myBorderlessWindow setHasShadow:YES];
        
		newOrigin.x = newOrigin.x+16.0;
		newOrigin.y = newOrigin.y+16.0;
		[myBorderlessWindow setFrameOrigin:newOrigin];
        
		[myBorderlessWindow orderFront:self];
        
		[super mouseDown:theEvent];
		[myBorderlessWindow orderOut:self];
	}
}

@end
