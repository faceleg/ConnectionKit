//
//  APProductAttributesCell.h
//  Amazon List
//
//  Created by Mike on 30/12/2006.
//  Copyright 2006-2009 Karelia Software. All rights reserved.
//
//	Displays information about an APAmazonProduct in a neatly formatted
//	single or double line fashion.


#import <Cocoa/Cocoa.h>
#import "SandvoxPlugin.h"


@interface APProductAttributesCell : NSTextFieldCell
{
	KSVerticallyAlignedTextCell *myTextDrawingCell;
}

@end
