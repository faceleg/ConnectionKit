//
//  SVHTMLValidatorController.m
//  Sandvox
//
//  Created by Dan Wood on 2/16/10.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVValidatorWindowController.h"
#import "KSProgressPanel.h"
#import "KSSilencingConfirmSheet.h"
#import "SVHTMLContext.h"
#import "KTPage.h"
#import "SVRawHTMLGraphic.h"

#import "NSString+Karelia.h"
#import "KSURLUtilities.h"

#import "KSStringHTMLEntityUnescaping.h"
#import "KSStringXMLEntityEscaping.h"


@interface SVValidationHTMLContext : SVHTMLContext
{
	NSUInteger	_disabledPreviewObjectsCount;
}

@property (nonatomic) NSUInteger disabledPreviewObjectsCount;

@end

@implementation SVValidationHTMLContext

@synthesize disabledPreviewObjectsCount = _disabledPreviewObjectsCount;

- (id)initWithOutputWriter:(id <KSWriter>)output; // designated initializer
{
	if ((self = [super initWithOutputWriter:output]) != nil) {
		
		_disabledPreviewObjectsCount = 0;
	}
	return self;
}

// This override prevents scripts and such from being written for elements that are not "shouldPreviewWhenEditing"
// That's because we send the for-publishing HTML to the validator, and we don't want HTML that is marked as not-for-preview
// to be passed to the validator.
- (BOOL)shouldWriteServerSideScripts; { return NO; }

- (void)writeGraphic:(SVGraphic *)graphic;  // takes care of callout stuff for you
{
	if ([graphic respondsToSelector:@selector(shouldPreviewWhenEditing)])
	{
		SVRawHTMLGraphic *rawHTML = (SVRawHTMLGraphic *)graphic;
		if (![[rawHTML shouldPreviewWhenEditing] boolValue])
		{
			_disabledPreviewObjectsCount++;
		}
	}
	[super writeGraphic:graphic];
}

@end


@interface WebView (WebViewPrivate)

// Whitelists access from an origin (sourceOrigin) to a set of one or more origins described by the parameters:
// - destinationProtocol: The protocol to grant access to.
// - destinationHost: The host to grant access to.
// - allowDestinationSubdomains: If host is a domain, setting this to YES will whitelist host and all its subdomains, recursively.
+ (void)_addOriginAccessWhitelistEntryWithSourceOrigin:(NSString *)sourceOrigin destinationProtocol:(NSString *)destinationProtocol destinationHost:(NSString *)destinationHost allowDestinationSubdomains:(BOOL)allowDestinationSubdomains;

@end

@implementation SVValidatorWindowController

@synthesize validationReportString = _validationReportString;

- (void) dealloc
{
	self.validationReportString = nil;
	[super dealloc];
}

- (BOOL) validatePage:(KTPage *)page
	   windowForSheet:(NSWindow *)aWindow;
{
    SVValidationHTMLContext *context = [[SVValidationHTMLContext alloc] init];
	[context writeDocumentWithPage:page];
    
	NSUInteger disabledPreviewObjectsCount = context.disabledPreviewObjectsCount;	// this will help us warn about items we are not validating
    
	NSString *docTypeName = [SVHTMLContext nameOfDocType:KSHTMLWriterDocTypeHTML_5 localize:NO];
    
    NSString *pageSource = [[context outputStringWriter] string];
    [context release];
	
    NSString *charset = [[page master] valueForKey:@"charset"];
	
    BOOL result = [self validateSource:pageSource
							pageValidationType:kSandvoxPage
		   disabledPreviewObjectsCount:disabledPreviewObjectsCount
							   charset:charset
						 docTypeString:docTypeName
						windowForSheet:aWindow];
	return result;
}

- (BOOL) validateSource:(NSString *)pageSource
	 pageValidationType:(PageValidationType)pageValidationType
disabledPreviewObjectsCount:(NSUInteger)disabledPreviewObjectsCount
				charset:(NSString *)charset
		  docTypeString:(NSString *)docTypeString		// if null, use what is in prelude
		 windowForSheet:(NSWindow *)aWindow;
{
	BOOL isValid = NO;
#if DEBUG
	// pageSource = [@"fjsklfjdslkjfld <b><bererej>" stringByAppendingString:pageSource];		// TESTING -- FORCE INVALID MARKUP
#endif
	DJW((@"page source = %@", pageSource));
	NSStringEncoding encoding = [charset encodingFromCharset];
	NSData *pageData = [pageSource dataUsingEncoding:encoding allowLossyConversion:YES];
	
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"sandvox_source.html"];
	NSString *pathOut = [NSTemporaryDirectory() stringByAppendingPathComponent:@"validation.html"];
	NSString *pathHeaders = [NSTemporaryDirectory() stringByAppendingPathComponent:@"headers.txt"];
	
	[pageData writeToFile:path atomically:NO];
	
	// curl -F uploaded_file=@karelia.html -F ss=1 -F outline=1 -F sp=1 -F noatt=1 -F verbose=1  http://validator.w3.org/check
	NSString *argString = [NSString stringWithFormat:@"--max-time 9 -F uploaded_file=@%@ -F ss=1 -F verbose=1 --dump-header %@ http://validator.w3.org/check", path, pathHeaders];
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
		
		DJW((@"result = %@", resultingPageString));
		NSError *error;
		NSString *headers = [NSString stringWithContentsOfFile:pathHeaders encoding:NSUTF8StringEncoding error:&error];
		DJW((@"headers = %@", headers));
		NSDictionary *headerDict = [headers parseHTTPHeaders];
		
		int numErrors = [[headerDict objectForKey:@"X-W3C-Validator-Errors"] intValue];
		int numWarnings = [[headerDict objectForKey:@"X-W3C-Validator-Warnings"] intValue];
		isValid = [[headerDict objectForKey:@"X-W3C-Validator-Status"] isEqualToString:@"Valid"];	// Valid, Invalid, Abort
		NSString *explanation = nil;
		
		NSRange foundValidRange = [resultingPageString rangeBetweenString:@"<h2 class=\"valid\">" andString:@"</h2>"];
		if (NSNotFound != foundValidRange.location)
		{
			explanation = [[[resultingPageString substringWithRange:foundValidRange] condenseWhiteSpace] stringByUnescapingHTMLEntities];
		}
		
		// Set up any warning about disabled-preview objects here, since it might be shown on either the success alert OR the detailed warnings window.
		NSString *disabledPreviewNote = nil;
		switch (disabledPreviewObjectsCount)
		{
			case 1:
				disabledPreviewNote = NSLocalizedString(@"Please note that there was a raw HTML object that you have chosen not to be included in this validation.", @""); 
				break;
			default:
				disabledPreviewNote = [NSString stringWithFormat:NSLocalizedString(@"Please note that there were %d raw HTML objects that you have chosen not to be included in this validation.", @""), disabledPreviewObjectsCount]; 
				break;
		}
		
		NSString *disabledPreviewExplanation = NSLocalizedString(@"You may wish to use validator.w3.org to check your published website instead.", @"");
		
		if (isValid)	// no need to show HTML, just announce that it's OK
		{
			NSString *disabledPreviewWarningWithNewlines = @"";
			
			if (disabledPreviewObjectsCount)
			{
				disabledPreviewWarningWithNewlines = [NSString stringWithFormat:@"\n\n%@ %@", disabledPreviewNote, disabledPreviewExplanation];
			}
			
			if (explanation)
			{
				// DEPRECATED
				NSRunInformationalAlertPanelRelativeToWindow(
					 NSLocalizedString(@"Congratulations!  The HTML is valid.",@"Title of results alert"),
					 NSLocalizedString(@"The validator returned the following status message:\n\n%@%@",@""),
					 nil,nil,nil, aWindow, explanation, disabledPreviewWarningWithNewlines);				
			}
			else	// no explanation to show ... just show any disabled warning below.
			{
				// DEPRECATED
				NSRunInformationalAlertPanelRelativeToWindow(
					 NSLocalizedString(@"Congratulations!  The HTML is valid.",@"Title of results alert"),
						disabledPreviewWarningWithNewlines,
					 nil,nil,nil, aWindow );
			}
		}
		else
		{
			// show window
			NSString *errorCountString = nil;
			NSString *warningCountString = nil;
			NSString *explanation1 = nil;
			switch (numWarnings)
			{
				case 0:		// Note: zero warnings means that there will be some errors, otherwise we won't see this window
					warningCountString = NSLocalizedString(@"No warnings", @""); 
					break;
				case 1:
					warningCountString = NSLocalizedString(@"1 warning", @""); 
					explanation1 = NSLocalizedString(@"Here are some possible explanations for the warning:", @"SINGULAR Explanation Text for validator output");
					break;
				default:
					warningCountString = [NSString stringWithFormat:NSLocalizedString(@"%d warnings", @"<count> warnings"), numWarnings];
					explanation1 = NSLocalizedString(@"Here are some possible explanations for the warnings:", @"PLURAL Explanation Text for validator output");
					break;
			}
			
			// Check error count after warning count, so that having errors will override any mention of warnings in explanation1
			switch (numErrors)
			{
				case 0:
					errorCountString = NSLocalizedString(@"No errors", @""); 
					// Zero warnings mean there are warnings only, so don't override the above-defined explanation1
					break;
				case 1:
					errorCountString = NSLocalizedString(@"1 error", @""); 
					explanation1 = NSLocalizedString(@"Here are some possible explanations for the error:", @"SINGULAR Explanation Text for validator output");
					break;
				default:
					errorCountString = [NSString stringWithFormat:NSLocalizedString(@"%d errors", @"<count> errors"), numErrors];
					explanation1 = NSLocalizedString(@"Here are some possible explanations for the errors:", @"PLURAL Explanation Text for validator output");
					break;
			}
			
			NSString *windowTitleFormat = NSLocalizedString(@"Raw HTML Object Validator Results: %@, %@", "HTML Validator Window Title. Followed by <count> errors, <count> warnings");
			if (kSandvoxFragment != pageValidationType)
			{
				windowTitleFormat = NSLocalizedString(@"Page Validator Results: %@, %@", "HTML Validator Window Title. Followed by <count> errors, <count> warnings");
			}
			[[self window] setTitle:[NSString stringWithFormat:windowTitleFormat, errorCountString, warningCountString]];
			[[self window] setFrameAutosaveName:@"ValidatorWindow"];
			[self showWindow:nil];
			
			WebPreferences *newPrefs = [[[WebPreferences alloc] initWithIdentifier:@"validator"] autorelease];
			[newPrefs setUserStyleSheetEnabled:YES];
			NSString *cssPath = [[NSBundle mainBundle] pathForResource:@"validator" ofType:@"css"];
			[newPrefs setUserStyleSheetLocation:[NSURL fileURLWithPath:cssPath]];
			[oWebView setPreferences:newPrefs];
			
			// Insert our own message
			NSString *headline = NSLocalizedString(@"Explanation and Impact", @"Header, shown above Explanation Text for validator output");
			
			// NSString *appIconPath = [[NSBundle mainBundle] pathForImageResource:@"AppIcon"];
			NSURL *appIconURL = nil; // [NSURL fileURLWithPath:appIconPath];
			
			// WORK-AROUND ... can't load file:// when I have baseURL set, which I need for links to "#" sections to work!
			appIconURL = [NSURL URLWithString:@"http://www.karelia.com/images/SandvoxAppIcon128.png"];
			
			// I tried this but it didn't do the job.  Maybe I'm doing it wrong.  DJW aked for a real API with a radar.
			// [WebView _addOriginAccessWhitelistEntryWithSourceOrigin:@"localhost" destinationProtocol:@"file" destinationHost:@"localhost" allowDestinationSubdomains:NO];
			
			NSMutableString *replacementString = [NSMutableString stringWithString:@"</h2>"];	// start with what we're going to replace
			[replacementString appendFormat:@"\n<h3>%@</h3>\n<div id='appicon'><img src='%@' width='64' height='64' alt='' /></div>\n<div id='explain-impact'>\n", [KSXMLWriter stringFromCharacters:headline], [appIconURL absoluteString]];
			
			
			NSString *explanation1a = NSLocalizedString(@"Some HTML that you have entered is invalid", @"Explanation Text for validator output");
			NSString *fix1a = NSLocalizedString(@"Fix the HTML so that it no longer returns any errors or warnings", @"Suggestion for the user to perform");
			if (kSandvoxPage == pageValidationType)
			{
				explanation1a = NSLocalizedString(@"Some HTML, that you placed on raw HTML objects, is invalid", @"Explanation Text for validator output");
				fix1a = NSLocalizedString(@"Check the raw HTML objects on the page, and fix the offending HTML code so that they no longer return validation errors or warnings", @"Suggestion for the user to perform");
				
			}
			NSString *explanation1bFmt = NSLocalizedString(@"Some HTML is not acceptable for the specified document type: %@", @"Explanation Text for validator output");
			NSString *fix1b = NSLocalizedString(@"Change the HTML declaration to a less restrictive type", @"Suggestion for the user to perform");
			if (kSandvoxPage == pageValidationType)
			{
				explanation1bFmt = NSLocalizedString(@"Some HTML, that you placed on raw HTML objects, is not acceptable for the specified document type: %@", @"Explanation Text for validator output");
				
				fix1b = NSLocalizedString(@"Change the HTML declaration in the offending object(s) to be a less restrictive type", @"Suggestion for the user to perform");
				
			}
			else if (kNonSandvoxHTMLPage == pageValidationType)
			{
				// We won't be showing any doc type since it's not specified 
				explanation1bFmt = NSLocalizedString(@"Some HTML is not acceptable for the document type you have specified on the page", @"Explanation Text for validator output");
				explanation1bFmt = [explanation1bFmt stringByAppendingString:@"%@"]; // make it work generically with (non-showing) doc type
				
				fix1b = NSLocalizedString(@"Change the HTML declaration at the top to be a less restrictive type", @"Suggestion for the user to perform");
				
			}
			NSString *explanation1c = NSLocalizedString(@"You have chosen to include popular, but technically invalid markup", @"Explanation Text for validator output");
			if (kSandvoxPage == pageValidationType)
			{
				explanation1c = NSLocalizedString(@"You have chosen to include popular, but technically invalid markup, in raw HTML objects on this page", @"Explanation Text for validator output");
			}
			NSString *examples1c = NSLocalizedString(@"Examples: <embed>, <video>, <iframe>, <font>, <wbr>", @"Examples of HTML tags that may have problems");
			NSString *fix1c = NSLocalizedString(@"This kind of warning can usually be ignored but you may want to verify your page on several browsers", @"Suggestion for the user to perform");
			
			NSString *explanation1d = nil;	// won't use this explanation for objects, only for a full page
			NSString *fix1d = nil;
			if (kSandvoxPage == pageValidationType)
			{
				explanation1d = NSLocalizedString(@"Sandvox has a problem and has produced incorrect HTML", @"Explanation Text for validator output");
				fix1d = NSLocalizedString(@"This is not very likely, but if you can see that the invalid code is part of the Sandvox template, please [contact Karelia].", @"Suggestion for the user to perform -- the text between [ and ] will be hyperlinked");
			}
			
		
			
			
			if (!docTypeString) docTypeString = @"";		// make sure nil doctype is just not output
			
			[replacementString appendFormat:@"<p>%@</p>\n<dl style='font-size:0.8em; line-height:1.6em; margin-left:120px;'><dt style='display: list-item;'>%@</dt><dd style='font-style:italic;'>%@</dd><dt style='display: list-item;'>%@</dt><dd style='font-style:italic;'>%@</dd><dt style='display: list-item;'>%@</dt><dd><dd>%@</dd><dd style='font-style:italic;'>%@</dd>",
			 [KSXMLWriter stringFromCharacters:explanation1],
			 
			 [KSXMLWriter stringFromCharacters:explanation1a],
			 [KSXMLWriter stringFromCharacters:fix1a],
			 
			 // Explanation 1b -- put the doctype as boldface after escaping the format string (which won't mess up the %@)
			 [NSString stringWithFormat:[KSXMLWriter stringFromCharacters:explanation1bFmt], 
			  [NSString stringWithFormat:@"<b>%@</b>", docTypeString]],
			 [KSXMLWriter stringFromCharacters:fix1b],
			 
			 [KSXMLWriter stringFromCharacters:explanation1c],
			 [KSXMLWriter stringFromCharacters:examples1c],
			 [KSXMLWriter stringFromCharacters:fix1c]];
			
			
			if (kSandvoxPage == pageValidationType)
			{
				NSString *attachmentEnglish = @"The validation report will be attached to this message.";
				NSString *attachmentMessage = NSLocalizedString(@"The validation report will be attached to this message.", @"note to show somebody in the message window");
				
				// Silly hack to make sure that this is shown in both English and other language if we are not in English
				
				if (![attachmentMessage isEqualToString:attachmentEnglish])
				{
					attachmentMessage = [NSString stringWithFormat:@"%@\n%@", attachmentMessage, attachmentEnglish];
				}
				NSString *escapedAttachmentMessage = [[NSString stringWithFormat:@"\n\n\n%@", attachmentMessage] ks_stringByAddingPercentEscapesWithSpacesAsPlusCharacters:YES];
				NSString *escapedSubject = [@"Problem with HTML Validator" ks_stringByAddingPercentEscapesWithSpacesAsPlusCharacters:YES];
				NSString *linkString = [NSString stringWithFormat:@"<a href='sandvox:r/val=1&s=%@&d=%@'>", escapedSubject, escapedAttachmentMessage];
				
				// Hyperlink what's between the [ and the ]
				NSMutableString *newFix1d = [NSMutableString stringWithString:[KSXMLWriter stringFromCharacters:fix1d]];
				[newFix1d replace:@"[" with:linkString];
				[newFix1d replace:@"]" with:@"</a>"];
				
				[replacementString appendFormat:@"<dt style='display: list-item;'>%@</dt><dd style='font-style:italic;'>%@</dd>",
				 [KSXMLWriter stringFromCharacters:explanation1d],
				 newFix1d];
			}
			[replacementString appendString:@"</dl>\n"];
			
			
			if (disabledPreviewObjectsCount)
			{
				// Get the HTML badge, same as you see in the markup
				NSString *HTMLBadge = @"<span style=\"background:rgb(0,127,255); -webkit-border-radius:3px; padding:2px 5px; color:white; font-size:80%;\">HTML</span>";
				NSString *noteEscaped = [KSXMLWriter stringFromCharacters:disabledPreviewNote];
				NSString *noteEscapedBadged = [noteEscaped stringByReplacing:@"HTML" with:HTMLBadge];
				NSString *explanationEscaped = [KSXMLWriter stringFromCharacters:disabledPreviewExplanation];
				NSString *explanationHyperlinked = [explanationEscaped stringByReplacing:@"validator.w3.org" with:@"<a target='_blank' href='http://validator.w3.org/'>validator.w3.org</a>"];
				[replacementString appendFormat:@"<p>\n%@ %@\n</p>\n", noteEscapedBadged, explanationHyperlinked];
			}
			
			
			NSString *dontWorry = NSLocalizedString(
													@"Even if you get errors or warnings, your page will often render just fine in most browsers — many large companies have HTML that does not pass validation on their pages — but in some cases this will explain why your page does not look right.", @"Explanation Text for validator output");
			NSString *fixIfProblems = NSLocalizedString(
														@"If you are experiencing display problems on certain browsers, you should fix any error messages in this raw HTML object, or adjust the HTML style specified for this object to be a less restrictive document type.", @"Explanation Text for validator output");
			if (kSandvoxPage == pageValidationType)
			{
				fixIfProblems = NSLocalizedString(
												  @"If you are experiencing display problems on certain browsers, you should fix any error messages in the raw HTML objects that you put onto your page (including code injection), or adjust the HTML style specified for this page to be a less restrictive document type.", @"Explanation Text for validator output");
			}
			
			
			[replacementString appendFormat:@"<p><b>%@</b></p>\n<p>%@</p>\n",
			 [KSXMLWriter stringFromCharacters:dontWorry],
			 [KSXMLWriter stringFromCharacters:fixIfProblems]];
			
			[replacementString appendString:@"</div>\n"];	// finally done
			[resultingPageString replace:@"</h2>" with:replacementString];
			if (kSandvoxFragment == pageValidationType)
			{
				// Improve the (English) description a bit when we're just validating an object.
				// Note: This is not localized, since the validator is giving us English output only.
				[resultingPageString replace:@"while checking this document as" with:@"while checking this raw HTML object as"];
			}
			
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
				[resultingPageString replaceCharactersInRange:wherePostludeLines withString:@"</ol>\n<p style='color:gray;'>(Standard HTML page elements such as &lt;html&gt; and &lt;body&gt; have been hidden here.)</p>\n"];
				// Note: This is not localized, since the validator is giving us English output only.
			}
			
			// In case of feedback reporter use, put in a base HREF. I think I didn't want to do that when loading the URL though.
			self.validationReportString = [resultingPageString stringByReplacing:@"<head>" with:@"<head><base href='http://validator.w3.org' />"];
			[[oWebView mainFrame] loadHTMLString:resultingPageString
										 baseURL:[NSURL URLWithString:@"http://validator.w3.org/"]];
			
		}
	}
	else	// Don't show window; show alert sheet attached to document
	{
		NSAlert *alert = [[NSAlert alloc] init];
		[alert setMessageText:NSLocalizedString(@"Unable to Validate",@"Title of alert")];
		[alert setInformativeText:NSLocalizedString(@"Unable to contact validator.w3.org to perform the validation. You may wish to try again later.", @"error message")];
		
		[alert beginSheetModalForWindow:aWindow
						  modalDelegate:nil
						 didEndSelector:NULL
							contextInfo:NULL];
		
		[alert release];	// will be dealloced when alert is dismissed
	}
	return isValid;
}






@end
