//
//  KTNewsController.h
//  Marvel
//
//  Created by Dan Wood on 9/26/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class WebView, NTBoxView;

@interface KTNewsController : NSWindowController {

	IBOutlet WebView *oWebView;
	IBOutlet NTBoxView *oBox;
	
	NSMutableData *myRSSData;
	NSURLConnection	*myURLConnection;
}

+ (KTNewsController *)sharedNewsController;

- (void)loadRSSFeed;
- (IBAction) windowHelp:(id)sender;

@end
