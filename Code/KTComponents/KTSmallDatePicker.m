//
//  KTSmallDatePicker.m
//  TestDatePicker
//
//  Created by Terrence Talbot on 7/28/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTSmallDatePicker.h"
#import "KTSmallDatePickerCell.h"

@implementation KTSmallDatePicker

+ (void)cellClass;
{
	[KTSmallDatePickerCell class];
}

- (id)initWithFrame:(NSRect)frame;
{
	if ( nil == [super initWithFrame:frame] )
	{
		return nil;
	}
	else
	{
		[[self cell] setControlSize:NSSmallControlSize];
		[self setFont:[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSSmallControlSize]]];
		[self setDrawsBackground:YES];
		return self;
	}
}

@end
