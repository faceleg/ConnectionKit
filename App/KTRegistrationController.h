//
//  KTRegistrationController.h
//  Marvel
//
//  Created by Dan Wood on 10/28/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>


@interface KTRegistrationController : NSWindowController {

	IBOutlet NSTextField	*oRegistrationHeadlineField;
	IBOutlet NSTextField	*oCodeField;
	IBOutlet NSButton		*oRegButton;
	IBOutlet NSButton		*oClearRegButton;
	IBOutlet NSButton		*oLostCodeButton;
	IBOutlet WebView		*oWebView;
	IBOutlet NSBox			*oWebViewLine;
	
	IBOutlet NSTextField	*oPurchaseHeadlineField;
	IBOutlet NSProgressIndicator *oProgress;
	IBOutlet NSSegmentedControl *oForwardBack;
	IBOutlet NSSegmentedControl *oReloadOrStop;
	
	IBOutlet NSImageView *oLockImage;

	NSString *myRegCode;
	NSSize myOriginalSize;
	BOOL myIsExpanded;
	
	BOOL myIsLoadingInitialForm;
}

+ (KTRegistrationController *)sharedRegistrationController;
+ (KTRegistrationController *)sharedRegistrationControllerWithoutLoading;

- (IBAction) lostCode:(id)sender;
- (IBAction) buyKagi:(id)sender;
- (IBAction) buyPayPal:(id)sender;
- (IBAction) acceptRegistration:(id)sender;
- (IBAction) clearRegistration:(id)sender;
- (IBAction) expandWindow:(id)sender;
- (IBAction) contractWindow:(id)sender;
- (IBAction) forwardBack:(id)sender;
- (IBAction) reload:(id)sender;
- (IBAction) stopLoading:(id)sender;
- (IBAction) windowHelp:(id)sender;

@end
