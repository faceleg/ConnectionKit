//
//  NarrowPopUpButtonCell.h
//  Amazon List
//
//  Created by Mike on 19/01/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//
//	For some reason, a bordless NSPopupButton will not draw correctly below
//	a certain width.
//	This cell corrects the issue by simply telling super to draw in a larger
//	area.


#import <Cocoa/Cocoa.h>


@interface NarrowPopUpButtonCell : NSPopUpButtonCell
{

}

@end
