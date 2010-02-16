//
//  SVHTMLValidatorController.m
//  Sandvox
//
//  Created by Dan Wood on 2/16/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVHTMLValidatorController.h"
#import "KSProgressPanel.h"
#import "NSString+Karelia.h"
#import "KSSilencingConfirmSheet.h"


@implementation SVHTMLValidatorController


- (void) validateSource:(NSString *)pageSource charset:(NSString *)charset windowForSheet:(NSWindow *)aWindow;
{
	NSStringEncoding encoding = [charset encodingFromCharset];
	NSData *pageData = [pageSource dataUsingEncoding:encoding allowLossyConversion:YES];
	
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"sandvox_source.html"];
	NSString *pathOut = [NSTemporaryDirectory() stringByAppendingPathComponent:@"validation.html"];
	[pageData writeToFile:path atomically:NO];
	
	// curl -F uploaded_file=@karelia.html -F ss=1 -F outline=1 -F sp=1 -F noatt=1 -F verbose=1  http://validator.w3.org/check
	NSString *argString = [NSString stringWithFormat:@"-F uploaded_file=@%@ -F ss=1 -F verbose=1 http://validator.w3.org/check", path, pathOut];
	NSArray *args = [argString componentsSeparatedByString:@" "];
	
	NSTask *task = [[[NSTask alloc] init] autorelease];
	[task setLaunchPath:@"/usr/bin/curl"];
	[task setArguments:args];
	
	[[NSFileManager defaultManager] createFileAtPath:pathOut contents:[NSData data] attributes:nil];
	NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:pathOut];
	[task setStandardOutput:fileHandle];
	
#ifndef DEBUG
	// Non-debug builds should throw away stderr
	[task setStandardError:[NSFileHandle fileHandleForWritingAtPath:@"/dev/null"]];
#endif
	
	// Put up a progress panel. Alas, there is no cancel button.  How can we allow escape to cancel this?
	
    KSProgressPanel *progressPanel = [[KSProgressPanel alloc] init];
	[progressPanel setMessageText:NSLocalizedString(@"Fetching results…", @"Title of progress dialog")];
	[progressPanel setInformativeText:nil];
	[progressPanel setIndeterminate:YES];
	[progressPanel beginSheetModalForWindow:aWindow];

	[task launch];
	
	// Ideally I'd let some events come through like modal events.  Not sure if I want to start up a modal run loop?
	while ([task isRunning])
	{
		[NSThread sleepUntilDate:[NSDate distantPast]];
	}
	
	[progressPanel endSheet];
    [progressPanel release];

	int status = [task terminationStatus];
	
	if (0 == status)
	{
		[[oWebView mainFrame] loadData:[NSData dataWithContentsOfFile:pathOut]
							  MIMEType:@"text/html"
					  textEncodingName:@"utf-8" baseURL:[NSURL URLWithString:@"http://validator.w3.org/"]];
		[[self window] setTitle:NSLocalizedString(@"Validator Results", "HTML Validator Window Title")];
		[[self window] setFrameAutosaveName:@"ValidatorWindow"];
		[self showWindow:nil];
		
		// Scrape page to get status, to show success or failure.
		// (Do we want to show the success page?  If not, I'll need to show success sheet without loading window)
		BOOL isValid = NO;
		NSString *explanation = nil;
		NSString *resultingPageString = [[[NSString alloc] initWithContentsOfFile:pathOut
																		 encoding:NSUTF8StringEncoding
																			error:nil] autorelease];
		
		if (nil != resultingPageString)
		{
			NSRange foundValidRange = [resultingPageString rangeBetweenString:@"<h2 class=\"valid\">" andString:@"</h2>"];
			if (NSNotFound != foundValidRange.location)
			{
				isValid = YES;
				explanation = [resultingPageString substringWithRange:foundValidRange];
			}
		}
		
		if (isValid)		// not valid -- load the page, give them a way out!
		{
			[self performSelector:@selector(showValidationSuccessAlertMessage:)
					   withObject:explanation
					   afterDelay:0.0];
		}
		else
		{
			
			[self performSelector:@selector(showValidationResultsAlert)
					   withObject:nil
					   afterDelay:0.0];
		}
	}
	else	// Don't show window; show alert sheet attached to document
	{
		[KSSilencingConfirmSheet
		 alertWithWindow:aWindow
		 silencingKey:@"shutUpValidateError"
		 title:NSLocalizedString(@"Unable to Validate",@"Title of alert")
		 format:NSLocalizedString(@"Unable to contact validator.w3.org to perform the validation.", @"error message")];
	}

}



- (void)showValidationSuccessAlertMessage:(NSString *)explanation
{
	NSRunInformationalAlertPanelRelativeToWindow(
		 NSLocalizedString(@"HTML is Valid",@"Title of results alert"),
		 NSLocalizedString(@"The validator returned the following status message:\n\n%@",@""),
		 nil,nil,nil, [self window], explanation);
}


- (void)showValidationResultsAlert
{
    [KSSilencingConfirmSheet
     alertWithWindow:[self window]
     silencingKey:@"shutUpNotValidated"
     title:NSLocalizedString(@"Validation Results Loaded",@"Title of alert")
     format:NSLocalizedString(@"The results from the HTML validator have been loaded into this window.", @"validated message")];
}






@end
