//
//  KTCrashReporter.h
//  Marvel
//
//  Created by Dan Wood on 4/22/06.
//  Copyright 2006-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "KTAbstractBugReporter.h"

@class KSEmailAddressComboBox;

@interface KTCrashReporter : KTAbstractBugReporter
{
	IBOutlet NSTextView				*oReportTextView;
	IBOutlet KSEmailAddressComboBox	*oAddressComboBox;
	IBOutlet NSButton				*oIncludeConsoleCheckbox;
	IBOutlet NSButton				*oReportButton;
	IBOutlet NSButton				*oDontReportButton;
}

- (int)runAlert;
- (NSString *)pathOfLatestCrashReport:(NSString *)anAppName;

@end
