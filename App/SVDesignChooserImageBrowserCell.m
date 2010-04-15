//
//  SVDesignChooserImageBrowserCell.m
//  Sandvox
//
//  Created by Dan Wood on 12/8/09.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVDesignChooserImageBrowserCell.h"

@interface SVDesignChooserImageBrowserCell ()

- (NSRect) imageContainerFrame;

@end

@implementation SVDesignChooserImageBrowserCell


//---------------------------------------------------------------------------------
// imageFrame
//
// define where the image should be drawn
//---------------------------------------------------------------------------------
- (NSRect) imageFrame
{
	NSRect imageFrame = [super imageFrame];
	//get default imageFrame and aspect ratio
	
//	NSLog(@"%@", NSStringFromSize(imageFrame.size));
	// try to hack with the size so that image that was wider will get its full size somehow
	// Not sure if there is a better way to do this!
//	if (imageFrame.size.width > 100.0 || imageFrame.size.height > 65.0)	
//	{
//		imageFrame = NSInsetRect(imageFrame, -7, -(116.0 - imageFrame.size.height)/2.0 );
//	}
	return imageFrame;
}


//- (NSRect) selectionFrame
//{
//	return NSInsetRect([self imageContainerFrame], -4, -4);
//}

//- (NSRect) titleFrame;
//{
//	NSRect titleFrame = [super titleFrame];
//	titleFrame = NSInsetRect(titleFrame, -10, 0);
//	return titleFrame;
//}
//- (NSRect) subtitleFrame;
//{
//	NSRect subtitleFrame = [super subtitleFrame];
//	subtitleFrame = NSInsetRect(subtitleFrame, -10, 0);
//	return subtitleFrame;
//}



//----------------------------------------------------------------------------------------------------------------------


@end

