//
//  KTFeedbackReporter.m
//  Marvel
//
//  Created by Terrence Talbot on 9/25/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTFeedbackReporter.h"

#import "KT.h"
#import "KTAppDelegate.h"
#import "KTBundleManager.h"
#import "KTDesignManager.h"
#import "KTInfoWindowController.h"
#import <Sandvox.h>
#import "SandvoxPrivate.h"

// must match items in localized pop-up (pop-up is not programmatically built)
#define MENUITEM_FEATURE_REQUEST	NSLocalizedString(@"Feature Request", "Feature Request PopUpMenuItem")
#define MENUITEM_INQUIRY			NSLocalizedString(@"Inquiry", "Inquiry PopUpMenuItem")

#define MENUITEM_CRASH_DATA_LOSS	NSLocalizedString(@"Crash/Data Loss", "Crash/Data Loss PopUpMenuItem")
#define MENUITEM_DOCUMENT_EDITING	NSLocalizedString(@"Document Editing", "Document Editing PopUpMenuItem")
#define MENUITEM_HTML_CSS_RSS		NSLocalizedString(@"HTML/CSS/RSS", "HTML/CSS/RSS PopUpMenuItem")
#define MENUITEM_PAGE_DESIGNS		NSLocalizedString(@"Page Designs", "Page Designs PopUpMenuItem")
#define MENUITEM_PUBLISHING			NSLocalizedString(@"Publishing/Uploading", "Publishing/Uploading PopUpMenuItem")
#define MENUITEM_USER_EXPERIENCE	NSLocalizedString(@"User Experience", "User Experience PopUpMenuItem")
#define MENUITEM_OTHER				NSLocalizedString(@"Other", "Other PopUpMenuItem")

#define MENUITEM_FOLLOWUP			NSLocalizedString(@"Follow-up Previous Report", "Follow-up Previous Report PopUpMenuItem")

#define DELIVERY_ADDRESS            @"support@karelia.com"
#define EXTENSION_BZIP				@"bz2"


static NSString *sFeedbackSubmitURLString = @"https://ssl.karelia.com/bugsubmit/feedbackReporterSubmit.php";


@interface KTFeedbackReporter ( Private )
- (BOOL)reportIsFollowup;
- (NSAttributedString *)rtfdWithReport:(NSDictionary *)aReportDictionary;
- (NSString *)areaForClassification:(NSString *)aClassification;
- (NSString *)areaForSelectedClassification;
- (NSString *)reportDescription;
- (NSString *)reportExtra;
- (void)clearAndCloseWindow;
- (void)updateSubmitButtonState;
@end


@implementation KTFeedbackReporter

+ (id)sharedInstance
{
	static KTFeedbackReporter *feedbackReporterSharedInstance = nil;
	if ( nil == feedbackReporterSharedInstance )
	{
		feedbackReporterSharedInstance = [[KTFeedbackReporter alloc] init];
		
	}
	
    return feedbackReporterSharedInstance;
}

- (void)loadAndPrepareReportWindow
{
	[KTEmailAddressComboBox setWillAddAnonymousEntry:YES];
	[KTEmailAddressComboBox setWillIncludeNames:YES];
	(void)[NSBundle loadNibNamed:@"Feedback" owner:self];
	
	// add icons to classification menu items
	[oClassificationPopUp removeAllItems];
	
	[oClassificationPopUp addItemWithTitle:MENUITEM_FEATURE_REQUEST];
	[[oClassificationPopUp lastItem] setImage:[NSImage imageNamed:@"feedback_bulb"]];
//	[[oClassificationPopUp lastItem] setState:NO];

	[oClassificationPopUp addItemWithTitle:MENUITEM_INQUIRY];
	[[oClassificationPopUp lastItem] setImage:[NSImage imageNamed:@"feedback_qmark"]];

	[[oClassificationPopUp menu] addItem:[NSMenuItem separatorItem]];

	[oClassificationPopUp addItemWithTitle:MENUITEM_CRASH_DATA_LOSS];
	[[oClassificationPopUp lastItem] setImage:[NSImage imageNamed:@"feedback_redbug"]];

	[oClassificationPopUp addItemWithTitle:MENUITEM_DOCUMENT_EDITING];
	[[oClassificationPopUp lastItem] setImage:[NSImage imageNamed:@"feedback_yellowbug"]];
	
	[oClassificationPopUp addItemWithTitle:MENUITEM_HTML_CSS_RSS];
	[[oClassificationPopUp lastItem] setImage:[NSImage imageNamed:@"feedback_yellowbug"]];
	
	[oClassificationPopUp addItemWithTitle:MENUITEM_PAGE_DESIGNS];
	[[oClassificationPopUp lastItem] setImage:[NSImage imageNamed:@"feedback_yellowbug"]];
	
	[oClassificationPopUp addItemWithTitle:MENUITEM_PUBLISHING];
	[[oClassificationPopUp lastItem] setImage:[NSImage imageNamed:@"feedback_yellowbug"]];
	
	[oClassificationPopUp addItemWithTitle:MENUITEM_USER_EXPERIENCE];
	[[oClassificationPopUp lastItem] setImage:[NSImage imageNamed:@"feedback_yellowbug"]];
	
	[oClassificationPopUp addItemWithTitle:MENUITEM_OTHER];
	[[oClassificationPopUp lastItem] setImage:[NSImage imageNamed:@"feedback_yellowbug"]];
	
	[[oClassificationPopUp menu] addItem:[NSMenuItem separatorItem]];

	[oClassificationPopUp addItemWithTitle:MENUITEM_FOLLOWUP];
	[[oClassificationPopUp lastItem] setImage:[NSImage imageNamed:@"feedback_reply"]];
	[[oClassificationPopUp lastItem] setState:NO];

	// clear fields
	[oDetailsTextView setString:@""];		// zero width space there so we don't lose font
	[oDetailsTextView setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];

	NSString *urlString = [[[KTAppDelegate sharedInstance] currentDocument] publishedSiteURL];
	if (nil == urlString || [urlString isEqualToString:@"http://unpublished.example.com/"])
	{
		urlString = @"";
	}
	[oURLTextField setStringValue:urlString];
	[oSummaryTextField setStringValue:@""];
	[oCaseNumberTextField setStringValue:@""];
	
	// hide case fields
	[oCaseNumberLabel setHidden:YES];
	[oCaseNumberTextField setHidden:YES];
	
	// hide bug directions
	//[oBugDirectionsTextField setHidden:YES];
	//[oBugDirectionsButton setHidden:YES];
	
	// select Inquiry
	[oClassificationPopUp setTitle:MENUITEM_INQUIRY];
//	[oAttachConsoleSwitch setState:NO];
	[oAttachPreferencesSwitch setState:NO];
	[oAttachScreenshotSwitch setState:NO];
	
	[oCarbonCopySelfSwitch setState:[[NSUserDefaults standardUserDefaults] boolForKey:@"ccMyself"]];
	
	// set first responder to summary
	[oReportWindow makeFirstResponder:oSummaryTextField];
	
	// disable submit button until we have data
	[oSubmitButton setEnabled:NO];
	
	// set our defaults key
	[oAddressComboBox setDefaultsAddressKey:DEFAULTS_ADDRESS_KEY];
}

- (IBAction)showReportWindow:(id)sender
{
	[oReportWindow setFrameUsingName:@"Feedback Reporter"];
	[oReportWindow makeKeyAndOrderFront:nil];
}

#pragma mark subclass responsibility overrides

- (NSDictionary *)reportDictionary
{
	NSMutableDictionary *report = [NSMutableDictionary dictionaryWithCapacity:25]; // 25 possible keys
	
	// possible keys:
	//  customerEmail
	NSString *attachmentOwner = nil;
    NSString *emailAddress = nil;
	if ( ![oAddressComboBox addressIsAnonymous] )
	{
		emailAddress = [oAddressComboBox address];
		[report setValue:emailAddress forKey:@"customerEmail"];
		
		NSRange range = [emailAddress rangeOfString:@"@"];
		if (NSNotFound != range.location)
		{
			attachmentOwner = [emailAddress substringToIndex:range.location];
		}
		else
		{
			attachmentOwner = emailAddress;		// use the whole thing.
		}
	}
	else
	{
		attachmentOwner = ANONYMOUS_ADDRESS;
	}
    
	//  classification
	[report setValue:[oClassificationPopUp titleOfSelectedItem] forKey:@"classification"];
	
	//  summary
	[report setValue:[oSummaryTextField stringValue] forKey:@"summary"];
	
	//  caseNumber
	if ( [self reportIsFollowup] )
	{
		NSString *caseNumber = [[oCaseNumberTextField stringValue] trimFirstLine];
		if ( [caseNumber isEqualToString:@""] )
		{
			caseNumber = @"---";
		}
		[report setValue:caseNumber forKey:@"caseNumber"];
	}
	
	//  details
    //   append email address, again, at end of report
    if ( (nil == emailAddress) || [emailAddress isEqualToString:@""] )
    {
        emailAddress = ANONYMOUS_ADDRESS;
    }
    NSString *details = [[oDetailsTextView string] trim];
    details = [details stringByAppendingFormat:@"\n\nURL: %@\n\nSubmitted by: %@", [oURLTextField stringValue], emailAddress];
	[report setValue:details forKey:@"details"];
	
	//  appName
	[report setValue:[self appName] forKey:@"appName"];
	
	//  appVersion
	[report setValue:[[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleShortVersionString"]
			  forKey:@"appVersion"];
	
	//  appBuildNumber
	[report setValue:[[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleVersion"]
			  forKey:@"appBuildNumber"];
	
	//  systemVerison
	[report setValue:[self systemVersion] forKey:@"systemVersion"];
	
	//  additionalPlugins
	NSString *plugins = [[[KTAppDelegate sharedInstance] bundleManager] pluginReportShowingAll:NO];
	[report setValue:plugins forKey:@"additionalPlugins"];
	
	//  additionalDesigns
	NSString *designs = [[[KTAppDelegate sharedInstance] designManager] designReportShowingAll:NO];
	[report setValue:designs forKey:@"additionalDesigns"];
	
	//  license
	NSString *license = [[KTAppDelegate sharedInstance] registrationReport];
	[report setValue:license forKey:@"license"];
	
	// ccMyself
	[[NSUserDefaults standardUserDefaults] setBool:[oCarbonCopySelfSwitch state] forKey:@"ccMyself"];
	if ( ([oCarbonCopySelfSwitch state] == YES)
		 && ![oAddressComboBox addressIsAnonymous] )
	{
		[report setValue:@"on" forKey:@"ccMyself"];
	}
	else
	{
		[report setValue:@"NO" forKey:@"ccMyself"];
	}
	
	// attachments
	NSMutableArray *attachments = [NSMutableArray array];
	[report setValue:attachments forKey:@"attachments"];
	
	// possible attachment keys:
	//  console
	if ( [oAttachConsoleSwitch state] == YES )
	{
		NSString *theLog = [self consoleLogFilteredForName:[self appName]];
		NSData *logAsData = [theLog dataUsingEncoding:NSUTF8StringEncoding];
		NSData *compressedLog = [logAsData compressBzip2];
		
		NSString *logName = [NSString stringWithFormat:@"console-%@.log", attachmentOwner];
		NSString *compressedName = [logName stringByAppendingPathExtension:EXTENSION_BZIP];
		
		KTFeedbackAttachment *attachment = [KTFeedbackAttachment attachmentWithFileName:compressedName data:compressedLog];
		[report setValue:attachment forKey:@"console"];
		[attachments addObject:@"console"];
	}
	
	//  screenshot1 = document window
	//  screenshot2 = document sheet, if any
	//  screenshot3 = inspector window, if visible
	// alternative: use screencapture to write a jpeg of the entire screen to the user's temp directory
	if ( [oAttachScreenshotSwitch state] == YES )
	{
		NSWindow *window = [[[[KTAppDelegate sharedInstance] currentDocument] windowController] window];
		NSImage *snapshot = [window snapshot];
		if ( nil != snapshot )
		{
			NSData *snapshotData = [snapshot JPEG2000RepresentationWithQuality:0.40];
			NSString *snapshotName = [NSString stringWithFormat:@"screenshot-%@.jp2", attachmentOwner];
			
			KTFeedbackAttachment *attachment = [KTFeedbackAttachment attachmentWithFileName:snapshotName 
																					   data:snapshotData];
			[report setValue:attachment forKey:@"screenshot1"];
			[attachments addObject:@"screenshot1"];
		}
		
		// Also attach any sheet (host setup, etc.)
		if (nil != [window attachedSheet])
		{
			snapshot = [[window attachedSheet] snapshot];
			if ( nil != snapshot )
			{
				NSData *snapshotData = [snapshot JPEG2000RepresentationWithQuality:0.40];
				NSString *snapshotName = [NSString stringWithFormat:@"sheet-%@.jp2", attachmentOwner];
				
				KTFeedbackAttachment *attachment = [KTFeedbackAttachment attachmentWithFileName:snapshotName data:snapshotData];
				[report setValue:attachment forKey:@"screenshot2"];
				[attachments addObject:@"screenshot2"];
			}
		}
		
		// Attach inspector, if visible
		KTInfoWindowController *sharedController = [KTInfoWindowController sharedInfoWindowControllerWithoutLoading];
		if ( nil != sharedController )
		{
			NSWindow *infoWindow = [sharedController window];
			if ( [infoWindow isVisible] )
			{
				snapshot = [infoWindow snapshot];
				if ( nil != snapshot )
				{
					NSData *snapshotData = [snapshot JPEG2000RepresentationWithQuality:0.40];
					NSString *snapshotName = [NSString stringWithFormat:@"inspector-%@.jp2", attachmentOwner];
					
					KTFeedbackAttachment *attachment = [KTFeedbackAttachment attachmentWithFileName:snapshotName data:snapshotData];
					[report setValue:attachment forKey:@"screenshot3"];
					[attachments addObject:@"screenshot3"];
				}
			}
		}
	}
	
	//  otherAttachment		
	
	return [NSDictionary dictionaryWithDictionary:report];
}

- (NSAttributedString *)rtfdWithReport:(NSDictionary *)aReportDictionary
{
	NSString *leftDoubleQuote = NSLocalizedString(@"\\U201C", "left double quote");
	NSString *rightDoubleQuote = NSLocalizedString(@"\\U201D", "right double quote");
	
	NSString *appName = [aReportDictionary valueForKey:@"appName"];
	
	NSString *subject;
	if ( [self reportIsFollowup] )
	{
		subject = [NSString stringWithFormat:@"Re: (Case %@) %@", [aReportDictionary valueForKey:@"caseNumber"], [aReportDictionary valueForKey:@"summary"]];
	}
	else
	{
		subject = [aReportDictionary valueForKey:@"summary"];
	}
	
	NSString *customerAddress = [aReportDictionary valueForKey:@"customerEmail"];
	if ( nil == customerAddress )
	{
		customerAddress = ANONYMOUS_ADDRESS;
	}
	
	NSString *messageWithHeaders = [NSString stringWithFormat:NSLocalizedString(@"\nThis is a %@ Feedback Report. Getting good feedback is essential for continually improving %@. Please email the contents of this document to %@ with the subject %@%@%@. Once sent, you may remove the file at your convenience. Thank you.\n\n", "format: This is a Feedback Report."), appName, appName, DELIVERY_ADDRESS, leftDoubleQuote, subject, rightDoubleQuote];
	
	// add Date, From, Subject, To, mirroring Mail
	messageWithHeaders = [messageWithHeaders stringByAppendingFormat:@"From: %@\n", customerAddress];
	messageWithHeaders = [messageWithHeaders stringByAppendingFormat:@"To: %@\n", DELIVERY_ADDRESS];
	messageWithHeaders = [messageWithHeaders stringByAppendingFormat:@"Subject: %@\n", subject];
	messageWithHeaders = [messageWithHeaders stringByAppendingFormat:@"Date: %@\n", [[NSCalendarDate calendarDate] description]];
	
	// blank line
	messageWithHeaders = [messageWithHeaders stringByAppendingString:@"\n"];

	// add appName, appVersion, appBuildNumber, license, and systemVersion
	messageWithHeaders = [messageWithHeaders stringByAppendingFormat:@"Product: %@ %@(%@)\n", [aReportDictionary valueForKey:@"appName"], [aReportDictionary valueForKey:@"appVersion"], [aReportDictionary valueForKey:@"appBuildNumber"]];
	messageWithHeaders = [messageWithHeaders stringByAppendingFormat:@"Product License: %@\n", [aReportDictionary valueForKey:@"license"]];
	messageWithHeaders = [messageWithHeaders stringByAppendingFormat:@"Mac OS X: %@\n", [aReportDictionary valueForKey:@"systemVersion"]];

	// blank line
	messageWithHeaders = [messageWithHeaders stringByAppendingString:@"\n"];

	// add classification
	messageWithHeaders = [messageWithHeaders stringByAppendingFormat:@"Feedback Area: %@\n", [aReportDictionary valueForKey:@"classification"]];	
	
	// add message body
	messageWithHeaders = [messageWithHeaders stringByAppendingFormat:@"\nFeedback Details:\n%@", [aReportDictionary valueForKey:@"details"]];
	
	// blank lines
	messageWithHeaders = [messageWithHeaders stringByAppendingString:@"\n\n"];

	//	additionalPlugins
	messageWithHeaders = [messageWithHeaders stringByAppendingFormat:@"Additional Plugins:\n%@\n", [aReportDictionary valueForKey:@"additionalPlugins"]];
	
	//	additionalDesigns
	messageWithHeaders = [messageWithHeaders stringByAppendingFormat:@"Additional Designs:\n%@\n", [aReportDictionary valueForKey:@"additionalDesigns"]];
	
			
	// roll up into an attributed string so we can add attachments
	NSMutableAttributedString *rtfdString = [[NSMutableAttributedString alloc] initWithString:messageWithHeaders];
	
	NSArray *attachments = [aReportDictionary valueForKey:@"attachments"];
	// add attachments
	if ( [attachments count] > 0 )
	{
		[rtfdString appendAttributedString:[[[NSAttributedString alloc] initWithString:@"\nAttachments:\n\n"] autorelease]];
		
		NSEnumerator *e = [attachments objectEnumerator];
		NSString *attachmentName = nil;
		while ( attachmentName = [e nextObject] )
		{
			// turn our feedback attachment into a filewrapper
			KTFeedbackAttachment *feedbackAttachment = [aReportDictionary valueForKey:attachmentName];
			NSData *feedbackAttachmentContents = [feedbackAttachment data];
			NSString *feedbackAttachmentFileName = [feedbackAttachment fileName];
			NSFileWrapper *fw = [[NSFileWrapper alloc] initRegularFileWithContents:feedbackAttachmentContents];
			[fw setPreferredFilename:feedbackAttachmentFileName];
			
			// turn our filewrapper into a text attachment
			NSTextAttachment *attachment = [[[NSTextAttachment alloc] initWithFileWrapper:fw] autorelease];
			NSAttributedString *attachmentString = [NSAttributedString attributedStringWithAttachment:attachment];
			[rtfdString appendAttributedString:attachmentString];
			NSAttributedString *fileName = [[[NSAttributedString alloc] initWithString:[fw preferredFilename]] autorelease];
			[rtfdString appendAttributedString:fileName];
			[rtfdString appendAttributedString:[[[NSAttributedString alloc] initWithString:@"\n\n"] autorelease]];
		}
	}
	
	return [rtfdString autorelease];
}

- (void)clearAndCloseWindow
{
	// clear fields and close window
	[oSummaryTextField setStringValue:@""];
	[oURLTextField setStringValue:@""];
	[oDetailsTextView setString:@""];		// zero width space there so we don't lose font
	[oCaseNumberTextField setStringValue:@""];
	[oCaseNumberTextField setHidden:YES];
	[oCaseNumberLabel setHidden:YES];
	//[oBugDirectionsTextField setHidden:YES];
	
	[oClassificationPopUp setTitle:MENUITEM_INQUIRY];
	[oAttachConsoleSwitch setState:NO];
	[oAttachPreferencesSwitch setState:NO];
	[oAttachScreenshotSwitch setState:NO];	
	
	[oSubmitButton setEnabled:NO];
    
	[oReportWindow orderOut:nil];
}

- (NSString *)defaultReportFileName
{
    return [NSString stringWithFormat:@"%@ %@", [self appName], NSLocalizedString(@"Feedback","Feedback FileName")];
}

- (NSURL *)submitURL
{
    return [NSURL URLWithString:sFeedbackSubmitURLString];
}

#pragma mark IBActions

- (IBAction)submitReport:(id)sender
{
    // save email address to defaults for next time
    [oAddressComboBox saveSelectionToDefaults];
    [super submitReport:sender];
}

- (IBAction)changeClassification:(id)sender
{
	BOOL selectedBug = NO;
	BOOL selectedFollowup = NO;
	
	typedef enum {
		yellowBug,
		redBug,
		noBug
	} BugIconType;
	
	BugIconType bugIcon = noBug;
	
	NSString *selection = [sender titleOfSelectedItem];
	
	if ( [selection isEqualToString:MENUITEM_FEATURE_REQUEST] )
	{
		//[oAttachConsoleSwitch setState:NO];
		//[oAttachPreferencesSwitch setState:NO];
		//[oAttachScreenshotSwitch setState:NO];
	}
	else if ( [selection isEqualToString:MENUITEM_INQUIRY] )
	{
		//[oAttachConsoleSwitch setState:NO];
		//[oAttachPreferencesSwitch setState:NO];
		//[oAttachScreenshotSwitch setState:NO];
	}
	else if ( [selection isEqualToString:MENUITEM_CRASH_DATA_LOSS] )
	{
		[oAttachConsoleSwitch setState:YES];
		//[oAttachPreferencesSwitch setState:YES];
		//[oAttachScreenshotSwitch setState:NO];
		selectedBug = YES;
		bugIcon = redBug;
	}
	else if ( [selection isEqualToString:MENUITEM_DOCUMENT_EDITING] )
	{
		//[oAttachConsoleSwitch setState:NO];
		//[oAttachPreferencesSwitch setState:NO];
		//[oAttachScreenshotSwitch setState:NO];
		selectedBug = YES;
		bugIcon = yellowBug;
	}
	else if ( [selection isEqualToString:MENUITEM_HTML_CSS_RSS] )
	{
		//[oAttachConsoleSwitch setState:NO];
		//[oAttachPreferencesSwitch setState:NO];
		//[oAttachScreenshotSwitch setState:NO];
		selectedBug = YES;
		bugIcon = yellowBug;
	}
	else if ( [selection isEqualToString:MENUITEM_PAGE_DESIGNS] )
	{
		//[oAttachConsoleSwitch setState:NO];
		//[oAttachPreferencesSwitch setState:NO];
		//[oAttachScreenshotSwitch setState:NO];
		selectedBug = YES;
		bugIcon = yellowBug;
	}
	else if ( [selection isEqualToString:MENUITEM_PUBLISHING] )
	{
		[oAttachConsoleSwitch setState:YES];
		//[oAttachPreferencesSwitch setState:YES];
		//[oAttachScreenshotSwitch setState:NO];
		selectedBug = YES;
		bugIcon = yellowBug;
	}
	else if ( [selection isEqualToString:MENUITEM_USER_EXPERIENCE] )
	{
		//[oAttachConsoleSwitch setState:NO];
		//[oAttachPreferencesSwitch setState:NO];
		//[oAttachScreenshotSwitch setState:NO];
		selectedBug = YES;
		bugIcon = yellowBug;
	}
	else if ( [selection isEqualToString:MENUITEM_OTHER] )
	{
		//[oAttachConsoleSwitch setState:NO];
		//[oAttachPreferencesSwitch setState:NO];
		//[oAttachScreenshotSwitch setState:NO];
		selectedBug = YES;
		bugIcon = yellowBug;
	}
	else if ( [selection isEqualToString:MENUITEM_FOLLOWUP] )
	{
		//[oAttachConsoleSwitch setState:NO];
		//[oAttachPreferencesSwitch setState:NO];
		//[oAttachScreenshotSwitch setState:NO];
		selectedFollowup = YES;
	}
	
	[oCaseNumberLabel setHidden:!selectedFollowup];
	[oCaseNumberTextField setHidden:!selectedFollowup];
	//[oBugDirectionsTextField setHidden:!selectedBug];
	//[oBugDirectionsButton setHidden:!selectedBug];
	
	if ( bugIcon == redBug )
	{
		[oBugDirectionsButton setImage:[NSImage imageNamed:@"feedback_redbug.png"]];
	}
	else
	{
		[oBugDirectionsButton setImage:[NSImage imageNamed:@"feedback_yellowbug.png"]];
	}
	
	if ( selectedFollowup )
	{
		[oReportWindow makeFirstResponder:oCaseNumberTextField];
	}
	else
	{
		[oReportWindow makeFirstResponder:oSummaryTextField];
	}
}

#pragma mark delegate notifications

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	if ( [[aNotification object] isEqual:oSummaryTextField] )
	{
		[self updateSubmitButtonState];
	}
}

- (void)textDidChange:(NSNotification *)aNotification
{
	if ( [[aNotification object] isEqual:oDetailsTextView] )
	{
		[self updateSubmitButtonState];
	}	
}

#pragma mark support

- (BOOL)reportIsFollowup
{
	NSString *classification = [oClassificationPopUp titleOfSelectedItem];
	return [classification isEqualToString:MENUITEM_FOLLOWUP];
}

- (void)updateSubmitButtonState
{
	[oSubmitButton setEnabled:(([[[oSummaryTextField stringValue] trimFirstLine] length] > 0) && ([[[oDetailsTextView string] trimFirstLine] length] > 0))];
}

@end
