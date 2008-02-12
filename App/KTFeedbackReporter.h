//
//  KTFeedbackReporter.h
//  Marvel
//
//  Created by Terrence Talbot on 9/25/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//


#import "KTAbstractBugReporter.h"

@class KTEmailAddressComboBox;

@interface KTFeedbackReporter : KTAbstractBugReporter
{
	IBOutlet NSPopUpButton			*oClassificationPopUp;
	IBOutlet NSTextField			*oURLTextField;
	IBOutlet NSTextField			*oSummaryTextField;
	IBOutlet NSTextView				*oDetailsTextView;
	IBOutlet KTEmailAddressComboBox	*oAddressComboBox;
	IBOutlet NSButton				*oAttachConsoleSwitch;
	IBOutlet NSButton				*oAttachScreenshotSwitch;
	IBOutlet NSButton				*oAttachPreferencesSwitch;
	IBOutlet NSButton				*oCarbonCopySelfSwitch;
	IBOutlet NSTextField			*oCaseNumberLabel;
	IBOutlet NSTextField			*oCaseNumberTextField;
	IBOutlet NSTextField			*oBugDirectionsTextField;
	IBOutlet NSButton				*oBugDirectionsButton;
	IBOutlet NSButton				*oSubmitButton;
}

- (IBAction)changeClassification:(id)sender;

@end

/* Classification choices:

	Feature Request
	Inquiry
	--
	Crash/Data Loss
	Document Editing
	HTML/CSS/RSS
	Page Designs
	Publishing/Uploading
	User Experience
	Other
	--
	Follow-up Previous Report
*/

