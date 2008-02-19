//
//  KTRegistrationController.m
//  Marvel
//
//  Created by Dan Wood on 10/28/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTRegistrationController.h"

#import "KT.h"
#import "KTApplication.h"
#import "KTAppDelegate.h"
#import "Registration.h"
#import <Sandvox.h>
#import "SandvoxPrivate.h"

static KTRegistrationController *sSharedRegistrationController = nil;

@interface WebView (WebKitHackaton)
-(void)setDrawsBackground:(BOOL)b;
@end

@interface KTRegistrationController ( Private )

- (NSString *)regCode;
- (void)setRegCode:(NSString *)aRegCode;
- (BOOL) gotRegistrationCode:(NSString *)aCode loadStart:(BOOL)aLoadStartPage;
- (NSHTTPCookie *)getRegCookie;

@end

@implementation KTRegistrationController


+ (KTRegistrationController *)sharedRegistrationController;
{
    if ( nil == sSharedRegistrationController ) {
        sSharedRegistrationController = [[self alloc] init];
    }
    return sSharedRegistrationController;
}

+ (KTRegistrationController *)sharedRegistrationControllerWithoutLoading;
{
    return sSharedRegistrationController;
}


- (id)init
{
    self = [super initWithWindowNibName:@"KTRegistration"];
    return self;
}

- (void)dealloc
{
	[self removeObserver:self forKeyPath:@"regCode"];

	[self setRegCode:nil];
	[super dealloc];
}

// If we are currently registered, update the fields

- (void) updateUserInterface;
{
	if (nil != gRegistrationString)
	{
		[oClearRegButton setHidden:NO];
		[oLostCodeButton setHidden:YES];
		[oRegButton setHidden:YES];

		if (gLicenseViolation)
		{
			[oRegistrationHeadlineField setStringValue:NSLocalizedString(@"License Violation: Too Many Copies of Sandvox are Simultaneously Running.",@"Headling showing that sandvox is running too many copies simultaneously.")];
		}
		else
		{
			[oRegistrationHeadlineField setStringValue:NSLocalizedString(@"Sandvox is already registered. Thank you.",@"Headling showing that sandvox is already registered")];
		}

		[oPurchaseHeadlineField setStringValue:NSLocalizedString(@"Upgrade Your License or Purchase Additional Licenses to Sandvox:",@"Prompt to purchase ADDITIONAL/Upgrade licenses")];
		
		[oCodeField setEditable:NO];
		[oCodeField setSelectable:NO];
		[oCodeField setEnabled:NO];
		
		// Now calculate summary 
		NSMutableString *buf = [NSMutableString string];
		if (nil != gLicensee)
		{
			[buf appendFormat:NSLocalizedString(@"Licensed to %@",@"Shows who the application is licensed to"), gLicensee];
		}
		else
		{
			[buf appendString:NSLocalizedString(@"Licensed",@"Just indicate that it's licensed, with no name.")];
		}
		if (kSingleLicense != gLicenseType)
		{
			switch (gLicenseType)
			{
				case kHouseholdLicense:
					[buf appendString:NSLocalizedString(@" - Household License",@"Append indication of license type")];
					break;
				case kSiteLicense:
				case kWorldwideLicense:
					[buf appendString:NSLocalizedString(@" - Site License",@"Append indication of license type")];
					break;
			}
		}
		if (gIsPro)
		{
			[buf appendString:NSLocalizedString(@" - Pro Edition",@"Append indication of license type")];
		}
		if (0 == gLicenseVersion)
		{
			[buf appendString:NSLocalizedString(@" (Expiring Trial License)",@"Append indication of trial license")];
		}
		[self setRegCode:buf];
	}
	else
	{
		[oClearRegButton setHidden:YES];
		[oLostCodeButton setHidden:NO];
		[oRegButton setHidden:NO];
		[oRegButton setEnabled:NO];		// initially not enabled until something's there

		[oRegistrationHeadlineField setStringValue:NSLocalizedString(@"Enter your registration key to unlock Sandvox:",@"Prompt to enter registration key (with a 'key' icon next to this text)")];
			
		[oPurchaseHeadlineField setStringValue:NSLocalizedString(@"Purchase your License to Sandvox:",@"Prompt to purchase license")];

		[oCodeField setEditable:YES];
		[oCodeField setSelectable:YES];
		[oCodeField setEnabled:YES];
	}
	
}

- (void) loadInitialForm
{
	myIsLoadingInitialForm = YES;
	NSString *registeredString = (nil != gRegistrationString ? [NSString stringWithFormat:@"?reg=%@", [gRegistrationString urlEncode]] : @"");
	[[oWebView mainFrame] loadRequest:
		[NSURLRequest requestWithURL:
			[NSURL URLWithString:[NSString stringWithFormat:@"https://ssl.karelia.com/store/embedded_buynow.html%@", registeredString]]
			cachePolicy:NSURLRequestReloadIgnoringCacheData
					 timeoutInterval:10.0]];

	[oForwardBack setHidden:YES];
	[oWebViewLine setHidden:YES];
}	
- (void)windowDidLoad
{
    [super windowDidLoad];
	NSWindow *window = [self window];
	[window center];
	
	[self updateUserInterface];

	NSRect windowFrame = [window frame];
	NSRect contentFrame = [NSWindow contentRectForFrameRect:windowFrame styleMask:[window styleMask]];
	myOriginalSize = contentFrame.size;

	if ([oWebView respondsToSelector:@selector(setDrawsBackground:)]) {
        [oWebView setDrawsBackground:NO];
    }
	
	
	// Try to get the cookie first
	NSHTTPCookie *regCookie = [self getRegCookie];
	if (nil != regCookie)
	{
		(void)[self gotRegistrationCode:[[regCookie value] urlDecode] loadStart:NO];
	}
	
	[self loadInitialForm];
	
	[self addObserver:self forKeyPath:@"regCode" options:(NSKeyValueObservingOptionNew) context:nil];


}

- (void)windowWillClose:(NSNotification *)notification;
{
	// Upon closing this window, perhaps open up the new/open dialog.  Not typical but this helps
	[[NSApp delegate] performSelector:@selector(applicationOpenUntitledFile:) withObject:NSApp afterDelay:0.0];
}

/*!	Changes to code
*/
- (void)observeValueForKeyPath:(NSString *)aKeyPath
                      ofObject:(id)anObject
                        change:(NSDictionary *)aChange
                       context:(void *)aContext
{
	BOOL hiliteRegButton = ([oCodeField isEnabled]) && nil != [self regCode] && ![[self regCode] isEqualToString:@""];
	[oRegButton setEnabled:hiliteRegButton];

//	if (hiliteRegButton)
//	{
//		[oRegButton setKeyEquivalent:@"\r"];	// redundant, but maybe useful
//		[[oRegButton window] setDefaultButtonCell:[toHilite cell]];
//		[[oRegButton window] enableKeyEquivalentForDefaultButtonCell];
//	}
//	else
//	{
//		[oRegButton setKeyEquivalent:@""];
//	}
}

- (IBAction) expandWindow:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	BOOL shouldAnimate = [defaults boolForKey:@"DoAnimations"];

	NSWindow *window = [self window];
	NSSize newSize = NSMakeSize(800,750);
	NSRect windowFrame = [window frame];
	NSRect contentFrame = [NSWindow contentRectForFrameRect:windowFrame styleMask:[window styleMask]];

	float heightChange = newSize.height - contentFrame.size.height;
	contentFrame.origin.y -= heightChange;
	contentFrame.size.height += heightChange;
	contentFrame.size.width = newSize.width;
	if (contentFrame.origin.y < 5)
	{
		contentFrame.origin.y = 5;	// don't let it get below the bottom of the screen
	}

	NSRect frameRect = [NSWindow frameRectForContentRect:contentFrame styleMask:[window styleMask]];
	[window setFrame:frameRect display:YES animate:shouldAnimate];
	myIsExpanded = YES;
}

- (IBAction) contractWindow:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	BOOL shouldAnimate = [defaults boolForKey:@"DoAnimations"];
	
	NSWindow *window = [self window];
	NSRect windowFrame = [window frame];
	NSRect contentFrame = [NSWindow contentRectForFrameRect:windowFrame styleMask:[window styleMask]];
	
	float heightChange = myOriginalSize.height - contentFrame.size.height;
	contentFrame.origin.y -= heightChange;
	contentFrame.size.height += heightChange;
	contentFrame.size.width = myOriginalSize.width;
	
	NSRect frameRect = [NSWindow frameRectForContentRect:contentFrame styleMask:[window styleMask]];
	[window setFrame:frameRect display:YES animate:shouldAnimate];
	myIsExpanded = NO;
}

- (NSHTTPCookie *)getRegCookie
{
	NSArray *candidateCookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:@"https://ssl.karelia.com/"]];
	NSEnumerator *theEnum = [candidateCookies objectEnumerator];
	NSHTTPCookie *cookie;
	
	while (nil != (cookie = [theEnum nextObject]) )
	{
		if ([[cookie name] isEqualToString:@"sandvoxLicenseCode"])
		{
			return cookie;
		}
	}
	return nil;
}	

#pragma mark -
#pragma mark Actions

- (IBAction) buyKagi:(id)sender;
{
	NSURL *url = [NSURL URLWithString:@"http://www.kagi.com/XXXXXXX"];
	[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:url];
}

- (IBAction) buyPayPal:(id)sender;
{




}

- (IBAction) lostCode:(id)sender
{
	NSURL *url = [NSURL URLWithString:@"https://ssl.karelia.com/store/lostcode.html"];
	[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:url];
}

- (IBAction) forwardBack:(id)sender;
{
	int selectedSegment = [sender selectedSegment];
	if (0 == selectedSegment)
	{
		WebBackForwardList *list = [oWebView backForwardList];
		WebHistoryItem *backItem = [list backItem];
		NSString *backURL = [backItem URLString];
		if (NSNotFound != [backURL rangeOfString:@"to_paypal"].location)
		{
			[self loadInitialForm];		// fake it by going back to the start
			[self contractWindow:nil];
		}
		else
		{
			[oWebView goBack:sender];
		}
	}
	else
	{
		[oWebView goForward:sender];
	}
}

- (void)saveRegistration;
{
	NSString *code = [self regCode];
	[[NSApp delegate] checkRegistrationString:code];
	
	// Write to hidden place, for next launch
	
	NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *path = [libraryPaths objectAtIndex:0];
	
	NSFileManager *fm = [NSFileManager defaultManager];
	(void) [fm createDirectoryAtPath:path attributes:nil];
	
	path = [path stringByAppendingPathComponent:[NSApplication applicationName]];
	(void) [fm createDirectoryAtPath:path attributes:nil];
	
	// obscure strings and file name that doesn't look like a license file
	path = [path stringByAppendingPathComponent:gFunnyFileName];	
	
	NSData *dataFromString = [code dataUsingEncoding:NSUTF8StringEncoding];
	NSData *binaryData = [dataFromString dataEncryptedWithPassword:[NSString stringWithFormat:@"%@%@", gFunnyFileName, NSUserName()]];
	// encrypt with that same file name PLUS the user name -- which means that the hidden file
	// won't be decryptable if you're running from another account.
	
	BOOL result = [binaryData writeToFile:path atomically:YES];
	if (!result)
	{
		NSLog(@"Unable to write to %@", path);
	}
}

- (IBAction) reload:(id)sender
{
	if (myIsLoadingInitialForm)
	{
		[self loadInitialForm];
	}
	else
	{
		[oWebView reload:sender];
	}
}

- (IBAction) stopLoading:(id)sender
{
	[oWebView stopLoading:sender];
}

- (BOOL)alertShowHelp:(NSAlert *)alert
{
	NSString *helpString = @"Registering_Sandvox";		// HELPSTRING
	return [NSHelpManager gotoHelpAnchor:helpString];
}

- (IBAction) acceptRegistration:(id)sender;
{
	[self saveRegistration];
	[self updateUserInterface];

	NSAlert *status = [[[NSAlert alloc] init] autorelease];
	
	[status setShowsHelp:YES];
	[status setDelegate:self];

	if (gRegistrationString)
	{
		[status setAlertStyle:NSInformationalAlertStyle];
		[status setMessageText:NSLocalizedString(@"Registration Key Accepted",@"")];
		[status setInformativeText:NSLocalizedString(@"You are now licensed to use Sandvox.\n\nPlease save your registration key in case you need to re-register the program in the future.\n\nYou should quit and re-launch Sandvox to update the menus to their fully registered state.",@"")];

		[status addButtonWithTitle:NSLocalizedString(@"I will save the registration key in a safe place.",@"Button prompting user not to lose code")];
}
	else
	{
		[status setAlertStyle:NSCriticalAlertStyle];
		[status setMessageText:NSLocalizedString(@"Invalid Registration Key",@"")];
		[status setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"The key you entered, \\U201C%@\\U201D, was not accepted. Please make sure all words are spelled exactly the same as the given code. (Try copying and pasting into the text field.)\n\nNote: Your registration key is a sequence of words, usually your name followed by three nonsense words.",@""), [self regCode]]];
		[oCodeField setEnabled:YES];	// allow user to try again futilely!
	}
	[status beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

#pragma mark -
#pragma mark WebKit

- (WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request
{
	unsigned int mask = NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask|NSResizableWindowMask;
	NSWindow *aWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(100,100,100,100) styleMask:mask backing:NSBackingStoreBuffered defer:YES];
	[aWindow setReleasedWhenClosed:YES];
	[aWindow setTitle:@"PayPal"];
	
	WebView *aWebView = [[[WebView alloc] initWithFrame:NSMakeRect(100,100,100,100) frameName:@"popup" groupName:@""] autorelease];
	
	[aWebView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
	[aWindow setContentView:aWebView];

	if (nil != request)
	{
		[[aWebView mainFrame] loadRequest:request];
	}
	
//	[aWindow makeKeyAndOrderFront:nil];

	return aWebView;
}

- (void) webView:(WebView *)sender decidePolicyForMIMEType:(NSString *) type request:(NSURLRequest *) 
   request frame:(WebFrame *)frame decisionListener:(id)listener {
    [listener use];
}

- (void)webView:(WebView *)webView decidePolicyForNewWindowAction:(NSDictionary *)actionInformation
		request:(NSURLRequest *)request
   newFrameName:(NSString *)frameName
	decisionListener:(id)listener {
	[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:[request URL]];
    [listener ignore];
}

- (BOOL) gotRegistrationCode:(NSString *)aCode loadStart:(BOOL)aLoadStartPage
{
	[self setRegCode:aCode];
	[self saveRegistration];
	[self updateUserInterface];
	
	if (aLoadStartPage)
	{
		[self loadInitialForm];
		[self contractWindow:nil];
	}
	
	[self performSelector:@selector(doAlert:) withObject:aCode afterDelay:0.0];

	BOOL result = (nil != gRegistrationString);
	return result;
}

- (void) doAlert:(NSString *)aCode
{
	NSAlert *status = [[[NSAlert alloc] init] autorelease];

	[status setShowsHelp:YES];
	[status setDelegate:self];
	
	if (nil != gRegistrationString)
	{
		[status setAlertStyle:NSInformationalAlertStyle];
		[status setMessageText:NSLocalizedString(@"Registration Key Accepted",@"")];
		[status setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"You are now licensed to use Sandvox.\n\nYou will also receive an e-mail with your registration key, \\U201C%@\\U201D.\n\nPlease save this key in case you need to re-register the program in the future.\n\nYou should quit and re-launch Sandvox to update the menus to their fully registered state.",@""), gRegistrationString]];
		
		[status beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
	}
	else
	{
		[status setAlertStyle:NSWarningAlertStyle];
		[status setMessageText:NSLocalizedString(@"Invalid Registration Key",@"")];
		[status setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"The key returned by the payment server, \\U201C%@\\U201D, was not accepted. Please try to enter the key manually, or submit feedback from the 'Help' menu if you are still having problems.",@""), aCode]];
		[status beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
	}
}	

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation
		request:(NSURLRequest *)request
		  frame:(WebFrame *)frame
		decisionListener:(id)listener
{
	BOOL shouldUse = YES;
    NSURL *url = [request URL];
	
	// ABOUT TO GO TO "COMPLETE" PAGE -- GRAB THE CODE AND REGISTER!
	if (![[url scheme] isEqualToString:@"http"] && ![[url scheme] isEqualToString:@"https"] && ![[url scheme] isEqualToString:@"about"] && ![[url scheme] isEqualToString:@"applewebdata"])
	{
		[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:url];
		shouldUse = NO;
	}
    else if (NSNotFound != [[url path] rangeOfString:@"completed.html"].location)
	{
		NSString *query = [url query];
		NSDictionary *queryParameters = [query queryParameters];

		NSString *code = [queryParameters objectForKey:@"code"];
		if (nil != code)
		{
			shouldUse = ![self gotRegistrationCode:code loadStart:YES];	// returns true if it was valid
		}
		
		NSString *conf = [queryParameters objectForKey:@"conf"];
		if (nil != conf)
		{
			NSHTTPCookie *confCookie = [NSHTTPCookie cookieWithProperties:
				[NSDictionary dictionaryWithObjectsAndKeys: 
					@".karelia.com", NSHTTPCookieDomain,
					[NSDate dateWithTimeIntervalSinceNow:(60 * 60 * 24 * 365 * 10)], NSHTTPCookieExpires,
					@"sandvoxLicenseConf", NSHTTPCookieName,
					conf, NSHTTPCookieValue,
					nil]];
			
			[[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:confCookie];
		}
    }
	// Paypal URL
	else if (NSNotFound != [[url host] rangeOfString:@"paypal.com"].location)
	{
		if (!myIsExpanded)
		{
			[self expandWindow:nil];
		}
		[oForwardBack setHidden:NO];
		[oReloadOrStop setHidden:NO];
		[oWebViewLine setHidden:NO];
	}
	// Starting Point or interstitial
	else if ( (NSNotFound != [[url host] rangeOfString:@"ssl.karelia.com"].location)
			  && (		(NSNotFound != [[url path] rangeOfString:@"embedded_buynow"].location)
					||	(NSNotFound != [[url path] rangeOfString:@"to_paypal"].location)
					||	(NSNotFound != [[url path] rangeOfString:@"error.html"].location)
					||	(NSNotFound != [[url path] rangeOfString:@"pending.html"].location)
					||	(NSNotFound != [[url path] rangeOfString:@"pdt.php"].location) ) )
	{
		[oWebViewLine setHidden:YES];
	}
	else if ([[url scheme] isEqualToString:@"about"]  || [[url scheme] isEqualToString:@"applewebdata"])
	{
		shouldUse = YES;
	}
	else	// Another URL -- open in browser
	{	
		[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:url];
		shouldUse = NO;
	}
	if (shouldUse) [listener use]; else [listener ignore];
}


- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame
{
	[oReloadOrStop setAction:@selector(stopLoading:)];
	[oReloadOrStop setLabel:[NSString stringWithUnichar:'x'] forSegment:0];
	[oReloadOrStop setToolTip:NSLocalizedString(@"Stop loading",@"tooltip for stop button")];
	[oReloadOrStop setHidden:NO];
	[oProgress startAnimation:nil];
}

- (void)webView:(WebView *)sender didCommitLoadForFrame:(WebFrame *)frame
{
	WebDataSource *dataSource = [frame dataSource];
	NSMutableURLRequest *request = [dataSource request];
	NSURL *url = [request URL];
	BOOL isSecure = [[url scheme] isEqualToString:@"https"];
	[oLockImage setHidden:!isSecure];
}

/*
- (void)webView:(WebView *)sender resource:(id)identifier didFinishLoadingFromDataSource:(WebDataSource *)dataSource;
{
	id <WebDocumentRepresentation>	representation = [dataSource representation];
	NSString *source = @"";
	if ([representation canProvideDocumentSource])
	{
		source = [representation documentSource];
	}
	//<!-- <sandvoxLicenseCode>FOOBAR</sandvoxLicenseCode> -->
	NSRange whereSandvoxLicenseCode = [source rangeBetweenString:@"<sandvoxLicenseCode>" andString:@"</sandvoxLicenseCode>"];
	if (NSNotFound != whereSandvoxLicenseCode.location)
	{
		NSString *sandvoxLicenseCode = [source substringWithRange:whereSandvoxLicenseCode];
		if (![sandvoxLicenseCode isEqualToString:@""])
		{
			(void)[self gotRegistrationCode:sandvoxLicenseCode  loadStart:NO];
		}
	}
#warning todo figure out how to maybe kill the web frame display, or refresh it, or something
}
*/

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
	if (frame == [oWebView mainFrame])
	{
		myIsLoadingInitialForm = NO;	// done loading initial form if it was loading
		
		if ([oWebView respondsToSelector:@selector(setDrawsBackground:)]) {
			[oWebView setDrawsBackground:NO];
		}

		[oProgress stopAnimation:nil];
		[oReloadOrStop setAction:@selector(reload:)];
		[oReloadOrStop setLabel:[NSString stringWithUnichar:0x21BB] forSegment:0];
		[oReloadOrStop setToolTip:NSLocalizedString(@"Reload web view",@"tooltip for reload button")];

		[oForwardBack setEnabled:[sender canGoBack] forSegment:0];
		[oForwardBack setEnabled:[sender canGoForward] forSegment:1];
	}
}

// codes here:
// 	http://developer.apple.com/documentation/Cocoa/Reference/Foundation/ObjC_classic/TypesAndConstants/FoundationTypes.html

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
	int code = [error code];
	NSString *domain = [error domain];
	if (code == NSURLErrorCancelled && [domain isEqualToString:NSURLErrorDomain]
		|| (code == WebKitErrorFrameLoadInterruptedByPolicyChange  && [domain isEqualToString:WebKitErrorDomain]) )
	{
		return;		// no need to complain
	}
	
	[oProgress stopAnimation:nil];
	[oReloadOrStop setAction:@selector(reload:)];
	[oReloadOrStop setLabel:[NSString stringWithUnichar:0x21BB] forSegment:0];
	[oReloadOrStop setToolTip:NSLocalizedString(@"Reload web view",@"tooltip for reload button")];

	[oForwardBack setEnabled:[sender canGoBack] forSegment:0];
	[oForwardBack setEnabled:[sender canGoForward] forSegment:1];

	
    // Only report feedback for the main frame.
    if (frame == [oWebView mainFrame])
	{
    	NSAlert *status = [[[NSAlert alloc] init] autorelease];
		
		[status setAlertStyle:NSWarningAlertStyle];
		[status setMessageText:NSLocalizedString(@"Error Loading Web Page",@"")];
		LOG((@"%@ %@", error, [error localizedDescription]));
		NSMutableString *s = [NSMutableString string];
		if (nil != [error localizedDescription])
		{
			[s appendFormat:@"%@\n\n", [error localizedDescription]];
		}
		if (nil != [error localizedFailureReason])
		{
			[s appendFormat:@"%@\n\n", [error localizedFailureReason]];
		}
		if (nil != [error localizedRecoverySuggestion])
		{
			[s appendFormat:@"%@\n\n", [error localizedRecoverySuggestion]];
		}
		
		[status setInformativeText:s];
		[status beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
		
		// Populate WebView with additional error message
		
		NSString *failingURLString = [[error userInfo] objectForKey:NSErrorFailingURLStringKey];
		if (nil != failingURLString)
		{
			NSURL *failingURL = [NSURL URLWithString:[failingURLString encodeLegally]];
			if (NSNotFound != [[failingURL path] rangeOfString:@"pdt.php"].location)
			{
				NSString *query = [failingURL query];
				NSDictionary *queryParameters = [query queryParameters];
				NSString *tx = [queryParameters objectForKey:@"tx"];
				
				NSString *pathInfo = [NSString stringWithFormat: NSLocalizedString(@"This message has been saved to your desktop as 'Sandvox-Paypal Error.html'.",@"")];
				NSString *message = NSLocalizedString(@"Your PayPal transaction was completed, but Sandvox was unable to reach Karelia's database server to generate your license key. Paypal will attempt to contact our server again in the next 24 hours, and we will email your key as soon as possible. If you do not receive an email after 24 hours, please contact Karelia, at support@karelia.com. Be sure to include this payment confirmation code in your message:",@"");
				NSString *html = [NSString stringWithFormat:@"<html><head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" /></head><body style=\"margin:50 20%%;\"><p style=\"font:18px 'Lucida Grande';\">%@ <b>%@</b></p><p style=\"font:11px 'Lucida Grande';\">%@<br /><br />%@</p></body></html>", [message escapedEntities], [tx escapedEntities], [pathInfo escapedEntities], [NSDate date]];
				[[html dataUsingEncoding:NSUTF8StringEncoding] writeToFile:[@"~/Desktop/Sandvox-Paypal Error.html" stringByExpandingTildeInPath] atomically:NO];
				[[oWebView mainFrame] loadHTMLString:html baseURL:nil];
			}
		}
		
	}	
}

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
	[self webView:sender didFailLoadWithError:error forFrame:frame];		// duplicate
}

#pragma mark -
#pragma mark Accessors


- (NSString *)regCode
{
    return myRegCode; 
}

- (void)setRegCode:(NSString *)aRegCode
{
	aRegCode = [aRegCode trimFirstLine];
    [aRegCode retain];
    [myRegCode release];
    myRegCode = aRegCode;
}

- (IBAction) clearRegistration:(id)sender;
{
	NSAlert *confirm = [[[NSAlert alloc] init] autorelease];

	[confirm setShowsHelp:YES];
	[confirm setDelegate:self];

	[confirm addButtonWithTitle:NSLocalizedString(@"Clear",@"Button title to clear registration")];
	[confirm addButtonWithTitle:NSLocalizedString(@"Cancel",@"Cancel Button")];
	[confirm setAlertStyle:NSWarningAlertStyle];
	
	[confirm setMessageText:NSLocalizedString(@"Are you sure you want to clear the registration key?",@"")];
	[confirm setInformativeText:NSLocalizedString(@"If you proceed, the Sandvox registration information for this computer will be removed.",@"")];
	
	[confirm beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(clearAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
	
}

- (void)clearAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
	if (returnCode == NSAlertFirstButtonReturn)
	{
		[self setRegCode:nil];
		[[NSApp delegate] checkRegistrationString:@""];
		[self updateUserInterface];
		[self loadInitialForm];

		// delete it from the registration file
		
		// Write to hidden place, for next launch
		
		NSFileManager *fm = [NSFileManager defaultManager];
		NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
		NSString *path = [libraryPaths objectAtIndex:0];
		path = [path stringByAppendingPathComponent:[NSApplication applicationName]];
		path = [path stringByAppendingPathComponent:gFunnyFileName];	
	
		[fm removeFileAtPath:path handler:nil];
		
		
		// Clear cookie
		
		NSHTTPCookie *regCookie = [self getRegCookie];
		if (nil != regCookie)
		{
			[[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:regCookie];
		}
	}
}

- (IBAction) windowHelp:(id)sender
{
	[NSApp showHelpPage:@"Purchasing_Sandvox"];	// HELPSTRING
}


@end
