//
//  KTCrashReporter.m
//  Marvel
//
//  Created by Dan Wood on 4/22/06.
//  Copyright 2006 Karelia Software. All rights reserved.
//

#import "KTCrashReporter.h"

#import "Debug.h"
#import "KT.h"
#import "KTApplication.h"
#import "KSEmailAddressComboBox.h"
#import "NSApplication+Karelia.h"

static NSString *sCrashSubmitURLString = @"https://secure.karelia.com/bugsubmit/KTCrashReporterSubmit.php";

#define DELIVERY_ADDRESS        @"support@karelia.com"


@interface KTCrashReporter ( Private )
- (NSString *)details;
@end


@implementation KTCrashReporter

- (int)runAlert
{
	// clear the details text
	[oReportTextView setString:@""];
	[oReportTextView setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];

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

- (void)loadAndPrepareReportWindow
{
	[KSEmailAddressComboBox setWillAddAnonymousEntry:YES];
	[KSEmailAddressComboBox setWillIncludeNames:YES];
	(void)[NSBundle loadNibNamed:@"Crash" owner:self];

	// set first responder to summary
	[oReportWindow makeFirstResponder:oReportTextView];
		
	// set our from address defaults key
	[oAddressComboBox setDefaultsAddressKey:DEFAULTS_ADDRESS_KEY];
}

- (void)clearAndCloseWindow
{
	[oReportWindow orderOut:nil];
}

- (NSString *)pathOfLatestCrashReport:(NSString *)anAppName
{
	NSString *result = nil;
	
	BOOL isDir = NO;
	NSFileManager *fm = [NSFileManager defaultManager];
	
	NSString *crashLogsFolder = [@"~/Library/Logs/CrashReporter/" stringByExpandingTildeInPath];
	if ( !([fm fileExistsAtPath:crashLogsFolder isDirectory:&isDir] && isDir) )
	{
		return nil; // no crash reports yet
	}
	
	NSString *crashLogName = nil;

	//if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_4)
	if (floor(NSAppKitVersionNumber) <= 824)
	{
		/* On a 10.4 - 10.4.x system */
		crashLogName = [anAppName stringByAppendingString: @".crash.log"];
	}
	else
	{
		/* Leopard or later system */
		// crash reports now look like @"Sandvox_2007-11-19-194855_atman.crash"
		// with the time of the crash as part of the filename
		// so we're going to brute force walk the directory and check the mtimes
		// of every entry that starts with anAppName -- any better ideas?
		NSString *latestLogPath = nil;
		NSDate *latestLogDate = nil;
		
		NSDirectoryEnumerator *e = [fm enumeratorAtPath:crashLogsFolder];
		[e skipDescendents];
		NSString *path = nil;
		while ( path = [e nextObject] )
		{
			if ( [path hasPrefix:anAppName] && [[path pathExtension] isEqualToString:@"crash"] )
			{
				NSDictionary *fileAttributes = [e fileAttributes];
				NSDate *modDate = [fileAttributes objectForKey:NSFileModificationDate];
				if ( nil == latestLogPath )
				{
					latestLogPath = [[path copy] autorelease];
					latestLogDate = [[modDate copy] autorelease];
				}
				else if ( NSOrderedDescending == [modDate compare:latestLogDate] )
				{
					latestLogPath = [[path copy] autorelease];
					latestLogDate = [[modDate copy] autorelease];
				}
 			}
		}
		
		if ( nil != latestLogPath )
		{
			crashLogName = latestLogPath;
		}
		else
		{
			return nil;
		}
	}
	
	OBASSERT(nil != crashLogName);
	result = [crashLogsFolder stringByAppendingPathComponent:crashLogName];
	
	OBASSERT(nil != result);
	return result;
}

- (NSDictionary *)reportDictionary
{
	NSMutableDictionary *report = [NSMutableDictionary dictionaryWithCapacity:9]; // 9 possible keys
	
	[report setValue:[NSApplication applicationName]	forKey:@"ScoutProject"];
	
	[report setValue:[oReportTextView string] forKey:@"ReportText"];

	// Crash Report
	NSString *currentReport = nil;
	
	NSString *crashLogPath = [self pathOfLatestCrashReport:[self appName]];
	if ( nil != crashLogPath )
	{
	// Fetch the newest report from the log.  Let's hope it's UTF-8.
	NSError *error = nil;
	NSString* crashLog = [NSString stringWithContentsOfFile:crashLogPath encoding:NSUTF8StringEncoding error:&error];
	NSArray* separateReports = [crashLog componentsSeparatedByString: @"\n\n**********\n\n"];
		currentReport = [separateReports count] > 0
		? [separateReports objectAtIndex: [separateReports count] -1]
		: crashLog;		// if you can't split into pieces, send the whole thing (in case this is the first)
	}

	if (nil == currentReport || [currentReport isEqualToString:@""])
	{
		if ( nil != crashLogPath )
		{
			currentReport = [NSString stringWithFormat:@"Could not read crash log at %@", crashLogPath];	// NOLOCALIZE
		}
		else
		{
			currentReport = [NSString stringWithFormat:@"Could not read crash log for %@", [self appName]];	// NOLOCALIZE
		}
	}
	
	[report setValue:currentReport forKey:@"CrashReport"];
	[report setValue:[self appName] forKey:@"app_name"];
    NSString *appBuildNumber = [[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleVersion"];
	[report setValue:appBuildNumber forKey:@"app_version"];
	
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

	
	
	if ([oIncludeConsoleCheckbox state])
	{
		NSString *theLog = [self consoleLogFilteredForName:[self appName]];
		[report setValue:theLog forKey:@"Log"];
	}
	
	return [NSDictionary dictionaryWithDictionary:report];
}

- (NSAttributedString *)rtfdWithReport:(NSDictionary *)aReportDictionary
{
	NSString *appName = [self appName];
	NSString *subject = [aReportDictionary valueForKey:@"Description"];
	NSString *customerAddress = [aReportDictionary valueForKey:@"Email"];
	
	NSString *messageWithHeaders = [NSString stringWithFormat:NSLocalizedString(@"\nThis is a %@ Crash Report. Getting good feedback is essential for continually improving %@. Please email the contents of this document to %@ with the subject \\U201C%@\\U201D. Once sent, you may remove the file at your convenience. Thank you.\n\n", "format: This is an Crash Report."), appName, appName, DELIVERY_ADDRESS, subject];
	
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
	messageWithHeaders = [messageWithHeaders stringByAppendingFormat:@"Area: %@\n", @"Crash Report"];	
	
	// add message body
	messageWithHeaders = [messageWithHeaders stringByAppendingFormat:@"\nDetails:\n%@", [aReportDictionary valueForKey:@"Extra"]];
	
	// blank lines
	messageWithHeaders = [messageWithHeaders stringByAppendingString:@"\n\n"];
    
	// roll up into an attributed string so we can add attachments
	NSMutableAttributedString *rtfdString = [[NSMutableAttributedString alloc] initWithString:messageWithHeaders];
		
	return [rtfdString autorelease];
}



- (NSString *)defaultReportFileName
{
    return [NSString stringWithFormat:@"%@ %@", [self appName], NSLocalizedString(@"Crash Report",
											  "Crash Report FileName")];
}

- (NSURL *)submitURL
{
    return [NSURL URLWithString:sCrashSubmitURLString];
}


@end
