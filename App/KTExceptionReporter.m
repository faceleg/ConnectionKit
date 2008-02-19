//
//  KTExceptionReporter.m
//  Marvel
//
//  Created by Terrence Talbot on 12/22/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTExceptionReporter.h"
#import "KTApplication.h"
#import <Sandvox.h>
#import "NSException+Karelia.h"

static NSString *sScoutSubmitURLString = @"https://ssl.karelia.com/bugsubmit/exceptionReporterSubmit.php";

//#define	DEFAULTS_ADDRESS_KEY	@"ExceptionEmailAddress"
#define DELIVERY_ADDRESS        @"support@karelia.com"


@interface KTExceptionReporter ( Private )
- (NSString *)details;
@end


@implementation KTExceptionReporter

+ (KTExceptionReporter *)sharedInstance
{
	static KTExceptionReporter *exceptionReporterSharedInstance = nil;
	if ( nil == exceptionReporterSharedInstance )
	{
		exceptionReporterSharedInstance = [[KTExceptionReporter alloc] init];
	}
	
	return exceptionReporterSharedInstance;
}

- (void)dealloc
{
	[self setException:nil];
	[super dealloc];
}

- (int)runAlertWithException:(NSException *)anException
                 messageText:(NSString *)theMessageText 
             informativeText:(NSString *)theInformativeText
{
	// set the message text
	/// defend against nil
	if (nil == theMessageText) theMessageText = @"";
	
	[oMessageTextField setStringValue:theMessageText];
	
	// set the informative text
	/// defend against nil
	if (nil == theInformativeText) theInformativeText = @"";
	[oInformativeTextField setStringValue:theInformativeText];
	
	// clear the details text
	[oReportTextView setString:@""];
	[oReportTextView setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];

	// set our exception
	[self setException:anException];
	
	// display window, modally
	int resultCode = [[NSApplication sharedApplication] runModalForWindow:oReportWindow];
	
	if ( NSCancelButton == resultCode )
	{
		[super cancelReport:nil];
		return resultCode;
	}
	
	// send the report
	[super submitReport:nil];
    return resultCode;
}

// we override the button actions to stop the modal window and return a value
- (IBAction)submitReport:(id)sender
{
	[[NSApplication sharedApplication] stopModalWithCode:NSOKButton];
    [oAddressComboBox saveSelectionToDefaults];
}

- (IBAction)cancelReport:(id)sender
{
	[[NSApplication sharedApplication] stopModalWithCode:NSCancelButton];
}

- (IBAction) windowHelp:(id)sender
{
	[NSApp showHelpPage:@"What_to_do_if_Sandvox_encounters_a_problem"];
}

- (void)loadAndPrepareReportWindow
{
	[KTEmailAddressComboBox setWillAddAnonymousEntry:YES];
	[KTEmailAddressComboBox setWillIncludeNames:YES];
	(void)[NSBundle loadNibNamed:@"Exception" owner:self];
			
	// set first responder to summary
	[oReportWindow makeFirstResponder:oReportTextView];
		
	// set our from address defaults key
	[oAddressComboBox setDefaultsAddressKey:DEFAULTS_ADDRESS_KEY];
}

- (void)clearAndCloseWindow
{
	[oReportWindow orderOut:nil];
	[self setException:nil];
}

- (NSDictionary *)reportDictionary
{
	NSMutableDictionary *report = [NSMutableDictionary dictionaryWithCapacity:9]; // 9 possible keys
	
	// ScoutUserName
	[report setValue:@"Terrence Talbot" forKey:@"ScoutUserName"];
	
	// ScoutProject
	[report setValue:[NSApplication applicationName]	forKey:@"ScoutProject"];
	
	// ScoutArea
	[report setValue:@"Exception" forKey:@"ScoutArea"];
	
	// Description
	NSString *summary = [NSString stringWithFormat:@"%@ (build %@)", [[self exception] traceName], [self appBuildNumber]];
	[report setValue:summary forKey:@"Description"];
	
	// Extra
	NSString *details = [self details];
    details = [self fixUpLineEndingsForScoutSubmit:details];
	[report setValue:details forKey:@"Extra"];
	
	// Email
	NSString *address = nil;
	if ( ![oAddressComboBox addressIsAnonymous] )
	{
		address = [oAddressComboBox address];
	}
	else
	{
		address = ANONYMOUS_ADDRESS;
	}
	[report setValue:address forKey:@"Email"];

	// ForceNewBug
	[report setValue:@"0" forKey:@"ForceNewBug"];
	
	// ScoutDefaultMessage
	[report setValue:@"OK" forKey:@"ScoutDefaultMessage"];
	
	// FriendlyResponse
	[report setValue:@"1" forKey:@"FriendlyResponse"];
		
	return [NSDictionary dictionaryWithDictionary:report];
}

- (NSAttributedString *)rtfdWithReport:(NSDictionary *)aReportDictionary
{
	NSString *leftDoubleQuote = NSLocalizedString(@"\\U201C", "left double quote");
	NSString *rightDoubleQuote = NSLocalizedString(@"\\U201D", "right double quote");

	NSString *appName = [self appName];
	NSString *subject = [aReportDictionary valueForKey:@"Description"];
	NSString *customerAddress = [aReportDictionary valueForKey:@"Email"];
	
	NSString *messageWithHeaders = [NSString stringWithFormat:NSLocalizedString(@"\nThis is a %@ Exception Report. Getting good feedback is essential for continually improving %@. Please email the contents of this document to %@ with the subject %@%@%@. Once sent, you may remove the file at your convenience. Thank you.\n\n", "format: This is an Exception Report."), appName, appName, DELIVERY_ADDRESS, leftDoubleQuote, subject, rightDoubleQuote];
	
	// add Date, From, Subject, To, mirroring Mail
	messageWithHeaders = [messageWithHeaders stringByAppendingFormat:@"From: %@\n", customerAddress];
	messageWithHeaders = [messageWithHeaders stringByAppendingFormat:@"To: %@\n", DELIVERY_ADDRESS];
	messageWithHeaders = [messageWithHeaders stringByAppendingFormat:@"Subject: %@\n", subject];
	messageWithHeaders = [messageWithHeaders stringByAppendingFormat:@"Date: %@\n", [[NSCalendarDate calendarDate] description]];
	
	// blank line
	messageWithHeaders = [messageWithHeaders stringByAppendingString:@"\n"];
    
	// add appName, appVersion, appBuildNumber, license, and systemVersion
	messageWithHeaders = [messageWithHeaders stringByAppendingFormat:@"Product: %@ %@(%@)\n", appName, [self appVersion], [self appBuildNumber]];
	messageWithHeaders = [messageWithHeaders stringByAppendingFormat:@"Mac OS X: %@\n", [self systemVersion]];
    
	// blank line
	messageWithHeaders = [messageWithHeaders stringByAppendingString:@"\n"];
    
	// add classification
	messageWithHeaders = [messageWithHeaders stringByAppendingFormat:@"Area: %@\n", @"Exception"];	
	
	// add message body
	messageWithHeaders = [messageWithHeaders stringByAppendingFormat:@"\nDetails:\n%@", [aReportDictionary valueForKey:@"Extra"]];
	
	// blank lines
	messageWithHeaders = [messageWithHeaders stringByAppendingString:@"\n\n"];
    
	// roll up into an attributed string so we can add attachments
	NSMutableAttributedString *rtfdString = [[NSMutableAttributedString alloc] initWithString:messageWithHeaders];
		
	return [rtfdString autorelease];
}

- (NSString *)details
{
    // start with separator
	NSString *report = @"--\n";

	// add details
	report = [NSString stringWithFormat:@"\n%@\n", [oReportTextView string]];

	// separator
	report = [report stringByAppendingString:@"--\n"];

	// add appName, appVersion, appBuildNumber, license, and systemVersion
	report = [report stringByAppendingFormat:@"Product: %@ %@(%@)\n", [self appName], [self appVersion], [self appBuildNumber]];
	report = [report stringByAppendingFormat:@"Mac OS X: %@\n", [self systemVersion]];
	
	// blank line
	report = [report stringByAppendingString:@"\n"];
	
	// add exception name and reason
	report = [report stringByAppendingFormat:@"Name: %@\n", [[self exception] name]];	
	report = [report stringByAppendingFormat:@"Reason: %@\n", [[self exception] reason]];
    
	report = [report stringByAppendingFormat:@"Symbolic Stack Trace = \"%@\"\n", [[self exception] stacktrace]];
	
    // add userInfo (includes raw stacktrace)
    report = [report stringByAppendingFormat:@"User Info:\n%@\n", [[self exception] userInfo]];

	if ([oIncludeConsoleCheckbox state])
	{
		NSString *theLog = [self consoleLogFilteredForName:[self appName]];
		report = [report stringByAppendingFormat:@"Console:\n%@\n\n", theLog];
	}
	return report;
}

- (NSString *)defaultReportFileName
{
    return [NSString stringWithFormat:@"%@ %@", [self appName], NSLocalizedString(@"Exception Report",
																				  "Exception Report FileName")];
}

- (NSException *)exception
{
	return myException;
}

- (void)setException:(NSException *)anException
{
	[anException retain];
	[myException release];
	myException = anException;
}

- (NSURL *)submitURL
{
    return [NSURL URLWithString:sScoutSubmitURLString];
}


@end
