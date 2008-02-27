//
//  KTExceptionReporter.h
//  Marvel
//
//  Created by Terrence Talbot on 12/22/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTAbstractBugReporter.h"

@class KSEmailAddressComboBox;

@interface KTExceptionReporter : KTAbstractBugReporter 
{
	IBOutlet NSTextField			*oMessageTextField;
	IBOutlet NSTextField			*oInformativeTextField;
	IBOutlet NSTextView				*oReportTextView;
	IBOutlet KSEmailAddressComboBox	*oAddressComboBox;
	IBOutlet NSButton				*oIncludeConsoleCheckbox;
	IBOutlet NSButton				*oReportButton;
	IBOutlet NSButton				*oDontReportButton;
	NSException *myException;
}

// displays oReportWindow modally as an "alert"
// returns standard runModal result code (either NSOKButton or NSCancelButton)
- (int)runAlertWithException:(NSException *)anException
                 messageText:(NSString *)theMessageText
             informativeText:(NSString *)theInformativeText;

// simple accessor
- (NSException *)exception;
- (void)setException:(NSException *)anException;

@end
