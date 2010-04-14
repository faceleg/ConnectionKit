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
	
	// try to hack with the size so that image that was wider will get its full size somehow
	// Not sure if there is a better way to do this!
	if (imageFrame.size.height < 65.0)	
	{
		imageFrame = NSInsetRect(imageFrame, -6, -(65.0 - imageFrame.size.height)/2.0 );
	}
	return imageFrame;
}



//---------------------------------------------------------------------------------
// selectionFrame
//
// make the selection frame a little bit larger than the default one
//---------------------------------------------------------------------------------
- (NSRect) selectionFrame
{
	return NSInsetRect([self imageContainerFrame], -4, -4);
}




//----------------------------------------------------------------------------------------------------------------------


@end

