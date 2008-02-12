//
//  KTTextFieldCell.h
//  Marvel
//
//  Created by Dan Wood on 5/24/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//
// Based on RSBrowserAddressCell courtesy of Brent Simmons of Ranchero Software

#import <Cocoa/Cocoa.h>


@interface KTTextFieldCell : NSTextFieldCell {

}


- (void) editWithFrame: (NSRect) aRect inView: (NSView *) controlView
				editor: (NSText *) textObj delegate: (id) anObject
				 event: (NSEvent *) theEvent;
- (void) selectWithFrame: (NSRect) aRect inView: (NSView *) controlView
				  editor: (NSText *) textObj delegate: (id) anObject
				   start: (int) selStart length: (int) selLength;	

- (void) drawWithFrame: (NSRect) cellFrame inView: (NSView *) controlView;


@end
