//
//  GeneralIndexPullDownButton.m
//  GeneralIndex
//
//  Created by Mike on 03/12/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "GeneralIndexPullDownButton.h"


@implementation GeneralIndexPopUpButtonCell

/*  This feels a pretty dirty solution, but it works. By overriding this method rather than calling -setPullsDown: you get what looks like a pull down button (arrow drawing, menu placement), but behaves like a popup.
 */
- (BOOL)pullsDown; { return YES; }

@end
