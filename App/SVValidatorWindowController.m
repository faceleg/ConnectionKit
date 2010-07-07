//
//  SVHTMLValidatorController.m
//  Sandvox
//
//  Created by Dan Wood on 2/16/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVValidatorWindowController.h"
#import "KSProgressPanel.h"
#import "NSString+Karelia.h"
#import "KSSilencingConfirmSheet.h"
#import "KSStringXMLEntityEscaping.h"

@interface WebView (WebViewPrivate)

// Whitelists access from an origin (sourceOrigin) to a set of one or more origins described by the parameters:
// - destinationProtocol: The protocol to grant access to.
// - destinationHost: The host to grant access to.
// - allowDestinationSubdomains: If host is a domain, setting this to YES will whitelist host and all its subdomains, recursively.
+ (void)_addOriginAccessWhitelistEntryWithSourceOrigin:(NSString *)sourceOrigin destinationProtocol:(NSString *)destinationProtocol destinationHost:(NSString *)destinationHost allowDestinationSubdomains:(BOOL)allowDestinationSubdomains;

@end

@implementation SVValidatorWindowController


- (BOOL) validateSource:(NSString *)pageSource charset:(NSString *)charset docTypeString:(NSString *)docTypeString windowForSheet:(NSWindow *)aWindow;
{
	BOOL isValid = NO;
#if DEBUG
	// pageSource = [@"fjsklfjdslkjfld <b><bererej>" stringByAppendingString:pageSource];		// TESTING -- FORCE INVALID MARKUP
#endif
	NSStringEncoding encoding = [charset encodingFromCharset];
	NSData *pageData = [pageSource dataUsingEncoding:encoding allowLossyConversion:YES];
	
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"sandvox_source.html"];
	NSString *pathOut = [NSTemporaryDirectory() stringByAppendingPathComponent:@"validation.html"];
	NSString *pathHeaders = [NSTemporaryDirectory() stringByAppendingPathComponent:@"headers.txt"];

	[pageData writeToFile:path atomically:NO];
	
	// curl -F uploaded_file=@karelia.html -F ss=1 -F outline=1 -F sp=1 -F noatt=1 -F verbose=1  http://validator.w3.org/check
	NSString *argString = [NSString stringWithFormat:@"--max-time 6 -F uploaded_file=@%@ -F ss=1 -F verbose=1 --dump-header %@ http://validator.w3.org/check", path, pathHeaders];
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
		// Scrape page to get status, to show success or failure.
		NSMutableString *resultingPageString = [[[NSMutableString alloc] initWithContentsOfFile:pathOut
																		 encoding:NSUTF8StringEncoding
																			error:nil] autorelease];
		
		// TODO: continue case 27254, parse headers.txt file instead of scraping.
		NSError *error;
		NSString *headers = [NSString stringWithContentsOfFile:pathHeaders encoding:NSUTF8StringEncoding error:&error];
		NSDictionary *headerDict = [headers parseHTTPHeaders];

		int numErrors = [[headerDict objectForKey:@"X-W3C-Validator-Errors"] intValue];
		int numWarnings = [[headerDict objectForKey:@"X-W3C-Validator-Warnings"] intValue];
		isValid = [[headerDict objectForKey:@"X-W3C-Validator-Status"] isEqualToString:@"Valid"];	// Valid, Invalid, Abort
		NSString *explanation = NSLocalizedString(@"(none provided)", "indicator that not explanation was provided to HTML validation success");	// needs to be scraped
		
		NSRange foundValidRange = [resultingPageString rangeBetweenString:@"<h2 class=\"valid\">" andString:@"</h2>"];
		if (NSNotFound != foundValidRange.location)
		{
			explanation = [[[resultingPageString substringWithRange:foundValidRange] condenseWhiteSpace] stringByUnescapingHTMLEntities];
		}
		
		if (isValid)	// no need to show HTML, just announce that it's OK
		{
			NSRunInformationalAlertPanelRelativeToWindow(
				NSLocalizedString(@"Congratulations!  The HTML is valid.",@"Title of results alert"),
				NSLocalizedString(@"The validator returned the following status message:\n\n%@",@""),
				nil,nil,nil, aWindow, explanation);
		}
		else
		{
			// show window
			NSString *errorCountString = nil;
			NSString *warningCountString = nil;
			switch (numErrors)
			{
				case 0: errorCountString = NSLocalizedString(@"No errors", @""); break;
				case 1: errorCountString = NSLocalizedString(@"1 error", @""); break;
				default: errorCountString = [NSString stringWithFormat:NSLocalizedString(@"%d errors", @"<count> errors"), numErrors]; break;
			}
			switch (numWarnings)
			{
				case 0: warningCountString = NSLocalizedString(@"No warnings", @""); break;
				case 1: warningCountString = NSLocalizedString(@"1 warning", @""); break;
				default: warningCountString = [NSString stringWithFormat:NSLocalizedString(@"%d warnings", @"<count> warnings"), numWarnings]; break;
			}
			
			[[self window] setTitle:[NSString stringWithFormat:NSLocalizedString(@"Validator Results: %@, %@", "HTML Validator Window Title. Followed by <count> errors, <count> warnings"), errorCountString, warningCountString]];
			[[self window] setFrameAutosaveName:@"ValidatorWindow"];
			[self showWindow:nil];
			
			WebPreferences *newPrefs = [[[WebPreferences alloc] initWithIdentifier:@"validator"] autorelease];
			[newPrefs setUserStyleSheetEnabled:YES];
			NSString *cssPath = [[NSBundle mainBundle] pathForResource:@"validator" ofType:@"css"];
			[newPrefs setUserStyleSheetLocation:[NSURL fileURLWithPath:cssPath]];
			[oWebView setPreferences:newPrefs];
			
			// Insert our own message
			NSString *headline = NSLocalizedString(@"Explanation and Impact", @"Header, shown above Explanation Text for validator output");
			NSString *explanation1 = NSLocalizedString(
@"Here are some possible explanations for the warnings:", @"Explanation Text for validator output");
			NSString *explanation1a = NSLocalizedString(@"The raw HTML that you have entered yourself is invalid", @"Explanation Text for validator output");
			NSString *fix1a = NSLocalizedString(@"Fix the HTML so that it no longer returns these warnings", @"Suggestion for the user to perform");
			
			NSString *explanation1bFmt = NSLocalizedString(@"The HTML is not acceptable for the specified document type: %@", @"Explanation Text for validator output");
			NSString *fix1b = NSLocalizedString(@"Change the HTML declaration to a less restrictive type", @"Suggestion for the user to perform");
			NSString *explanation1b = [NSString stringWithFormat:explanation1bFmt, docTypeString];
		
			NSString *explanation1c = NSLocalizedString(@"You have chosen to include popular, but technically invalid markup", @"Explanation Text for validator output");
			NSString *examples1c = NSLocalizedString(@"Examples: <embed>, <video>, <iframe>, <font>, <wbr>", @"Examples of HTML tags that may have problems");
			NSString *fix1c = NSLocalizedString(@"This kind of warning can usually be ignored but you may want to verify your page on several browsers", @"Suggestion for the user to perform");

			NSString *explanation1d = NSLocalizedString(@"Sandvox has a problem and has produced incorrect HTML", @"Explanation Text for validator output");
			NSString *fix1d = NSLocalizedString(@"This is not very likely, but if you can see that the invalid code is part of the Sandvox template, please contact Karelia by choosing the \"Send Feedback...\" menu", @"Suggestion for the user to perform");
														
			NSString *explanation2 = NSLocalizedString(
														  @"Even if you get warnings, your page will often render just fine in most browsers — most large companies have HTML that does not pass validation on their pages — but in some cases this will explain why your page does not look right.", @"Explanation Text for validator output");
			NSString *explanation3 = NSLocalizedString(
														  @"If you are experiencing display problems on certain browsers, you should fix any error messages in the HTML elements that you put onto your page (including code injection), or adjust the HTML style specified for this page to be a less restrictive document type.", @"Explanation Text for validator output");
		
			// NSString *appIconPath = [[NSBundle mainBundle] pathForImageResource:@"AppIcon"];
			NSURL *appIconURL = nil; // [NSURL fileURLWithPath:appIconPath];
			
			// WORK-AROUND ... can't load file:// when I have baseURL set, which I need for links to "#" sections to work!
			appIconURL = [NSURL URLWithString:@"http://www.karelia.com/images/SandvoxAppIcon128.png"];
			
			// I tried this but it didn't do the job.  Maybe I'm doing it wrong.  DJW aked for a real API with a radar.
			// [WebView _addOriginAccessWhitelistEntryWithSourceOrigin:@"localhost" destinationProtocol:@"file" destinationHost:@"localhost" allowDestinationSubdomains:NO];
			
			
			NSString *replacementString = [NSString stringWithFormat:@"</h2>\n<h3>%@</h3>\n<div id='appicon'><img src='%@' width='64' height='64' alt='' /></div>\n<div id='explain-impact'>\n<p>%@</p>\n<dl style='font-size:0.8em; line-height:1.6em; margin-left:120px;'><dt>%@</dt><dd style='font-style:italic;'>%@</dd><dt>%@</dt><dd style='font-style:italic;'>%@</dd><dt>%@</dt><dd><dd>%@</dd><dd style='font-style:italic;'>%@</dd><dt>%@</dt><dd style='font-style:italic;'>%@</dd></dl><p>%@</p>\n<p>%@</p>\n</div>\n",
										   [headline stringByEscapingHTMLEntities],
										   [appIconURL absoluteString],
										   [explanation1 stringByEscapingHTMLEntities],
										   
										   [explanation1a stringByEscapingHTMLEntities],
										   [fix1a stringByEscapingHTMLEntities],
										   
										   [explanation1b stringByEscapingHTMLEntities],
										   [fix1b stringByEscapingHTMLEntities],

										   [explanation1c stringByEscapingHTMLEntities],
										   [examples1c stringByEscapingHTMLEntities],
										   [fix1c stringByEscapingHTMLEntities],

										   [explanation1d stringByEscapingHTMLEntities],
										   [fix1d stringByEscapingHTMLEntities],

										   [explanation2 stringByEscapingHTMLEntities],
										   [explanation3 stringByEscapingHTMLEntities]];
			
			[resultingPageString replace:@"</h2>" with:replacementString];
			
			// Take out the source lines that are superfluous for raw HTML element validation.
			NSRange wherePreludeLines = [resultingPageString rangeFromString:@"<ol class=\"source\">" toString:@"&lt;!-- BELOW IS THE HTML THAT YOU SUBMITTED TO THE VALIDATOR --&gt;</li>"];
			if (NSNotFound != wherePreludeLines.location)
			{
				[resultingPageString replaceCharactersInRange:wherePreludeLines withString:@"<ol class=\"source\" start=\"9\">"];
			}
			NSRange wherePostludeLines = [resultingPageString rangeFromString:@"&lt;!-- ABOVE IS THE HTML THAT YOU SUBMITTED TO THE VALIDATOR --&gt;" toString:@"</ol>"];
			if (NSNotFound != wherePostludeLines.location)
			{
				// Not *that* easy to figure out the line number of the <li> so let's just make that an empty line and close out the list.
				[resultingPageString replaceCharactersInRange:wherePostludeLines withString:@"</ul></ol>"];
			}
			
			
			[[oWebView mainFrame] loadHTMLString:resultingPageString
										 baseURL:[NSURL URLWithString:@"http://validator.w3.org/"]];
			
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
	return isValid;
}






@end
