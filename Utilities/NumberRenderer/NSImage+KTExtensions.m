//
//  NSImage+KTExtensions.m
//  KTComponents
//
//  Copyright 2004-2011 Karelia Software. All rights reserved.
//

// $Id: NSImage+KTExtensions.m 3183 2007-03-30 07:48:35Z dwood $
// $Date: $

#import "NSImage+KTExtensions.h"




@implementation NSImage ( KTExtensions )

- (NSBitmapImageRep *)firstBitmap	// returns nil if no bitmap associated.
{
	NSBitmapImageRep *result = nil;
	NSArray *reps = [self representations];
	unsigned int i;
    
	for (i = 0 ; i < [reps count] ; i++ )
	{
		NSImageRep *theRep = [reps objectAtIndex:i];
		if ([theRep isKindOfClass:[NSBitmapImageRep class]])
		{
			result = (NSBitmapImageRep *)theRep;
			break;
		}
	}
	return result;
}


/*!	Find or create a bitmap. */
- (NSBitmapImageRep *)bitmap	// returns bitmap, or creates one.
{
	NSBitmapImageRep *result = [self firstBitmap];
    
	if (nil == result)		// didn't have one, create it.
	{
		int width, height;
		NSSize sz = [self size];
		width = sz.width;
		height = sz.height;
		[self lockFocus];
		result = [[[NSBitmapImageRep alloc]
			initWithFocusedViewRect:NSMakeRect(0.0, 0.0, (float)width, (float)height)] autorelease];
		[self unlockFocus];
	}
	return result;
}



- (NSData *)PNGRepresentation
{
	NSMutableDictionary*	props = [NSMutableDictionary dictionary];
	
	// Also, set the PNG to be interlaced.
	//[props setObject:[NSNumber numberWithBool:YES] forKey:NSImageInterlaced];
	
	NSData *result = [[self bitmap] representationUsingType:NSPNGFileType properties:props];
	
	return result;
}


- (NSData *)JPEGRepresentationWithQuality:(float)aQuality
{
	NSMutableDictionary *props;
	
	props = [NSMutableDictionary dictionary];
	
	
	// Also set our desired compression property, and make NOT progressive for the benefit of the flash-based viewer
	[props setObject:[NSNumber numberWithFloat:aQuality] forKey:NSImageCompressionFactor];
	[props setObject:[NSNumber numberWithBool:NO] forKey:NSImageProgressive];
	
	NSData *result = [[self bitmap] representationUsingType:NSJPEGFileType properties:props];
	
	return result;
}


@end


