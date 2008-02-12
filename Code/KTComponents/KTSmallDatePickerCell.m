//
//  KTSmallDatePickerCell.m
//  TestDatePicker
//
//  Created by Terrence Talbot on 7/28/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTSmallDatePickerCell.h"

@interface NSDatePickerCell (Undocumented)
- (id)_stepperCell;
- (void)_getTextAreaFrame:(struct _NSRect *)textArea 
		 stepperCellFrame:(struct _NSRect *)stepperFrame 
   forDatePickerCellFrame:(struct _NSRect)dateFrame;
@end

@implementation KTSmallDatePickerCell

- (id)_stepperCell;
{
	NSStepperCell *result = [super _stepperCell];  // allocates the stepper
	
	[result setControlSize:NSSmallControlSize];
	
	return result;
}

- (void)_getTextAreaFrame:(struct _NSRect *)textArea 
		 stepperCellFrame:(struct _NSRect *)stepperFrame 
   forDatePickerCellFrame:(struct _NSRect)dateFrame;
{
    [super _getTextAreaFrame:textArea stepperCellFrame:stepperFrame forDatePickerCellFrame:dateFrame];
    (*stepperFrame).origin.y += 1;
}

@end
