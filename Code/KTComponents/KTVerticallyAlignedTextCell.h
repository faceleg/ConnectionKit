//
//  KTVerticallyAlignedTextCell.h
//  KTComponents
//
//  Created by Mike on 04/01/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//
//  A subclass of NSTextFieldCell that can be vertically aligned
//  as well as horizontally.

#import <Cocoa/Cocoa.h>


typedef enum {
	KTTopTextAlignment = 0,
	KTVerticalCenterTextAlignment = 1,
	KTBottomTextAlignment = 2,
} KTVerticalTextAlignment;


@interface KTVerticallyAlignedTextCell : NSTextFieldCell
{
	KTVerticalTextAlignment	myVerticalAlignment;
}

- (KTVerticalTextAlignment)verticalAlignment;
- (void)setVerticalAlignment:(KTVerticalTextAlignment)alignment;

@end
