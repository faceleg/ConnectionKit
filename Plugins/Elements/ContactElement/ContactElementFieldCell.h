//
//  ContactElementFieldCell.h
//  ContactElement
//
//  Created by Mike on 17/05/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ContactElementFieldCell : NSTextFieldCell
{
	NSImageCell		*myLockIconCell;
	
	BOOL	myLocked;
}

- (BOOL)isLocked;
- (void)setLocked:(BOOL)locked;

@end
