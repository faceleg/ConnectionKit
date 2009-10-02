//
//  SVWebViewLoadingController.h
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KSTabViewController.h"
#import "SVWebViewController.h"


@protocol SVWebViewLoadControllerDelegate;


@interface SVWebViewLoadController : KSTabViewController <SVWebEditorViewControllerDelegate>
{
  @private
    SVWebViewController *_primaryController;    // loaded & probably on-screen
    SVWebViewController *_secondaryController;  // offscreen, ready to load into
    NSViewController    *_webViewLoadingPlaceholder;
    
    KTPage  *_page;
    
    BOOL    _needsLoad;
    
    id <SVWebViewLoadControllerDelegate>    _delegate;  // weak ref
}

// You should use this to create a controller as it will internally create the correct subcontrollers
- (id)init;

@property(nonatomic, retain, readonly) SVWebViewController *primaryWebViewController;
@property(nonatomic, retain, readonly) SVWebViewController *secondaryWebViewController;

// Setting the page will automatically mark controller as needsLoad = YES
@property(nonatomic, retain) KTPage *page;


#pragma mark Loading
@property(nonatomic) BOOL needsLoad;
- (void)load;
- (IBAction)updateWebView:(id)sender;
- (void)loadIfNeeded;


#pragma mark Delegate
@property(nonatomic, assign) id <SVWebViewLoadControllerDelegate> delegate;

@end


#pragma mark -


@protocol SVWebViewLoadControllerDelegate
// The controller is not in a position to open a page by itself; it lets somebody else decide how to
- (void)loadController:(SVWebViewLoadController *)sender openPage:(KTPage *)page;
@end


/*  CODE THAT THE ABOVE DELEGATE METHOD SHOULD DO SOMEWHERE ALONG THE LINE
 if (!thePage)
 {
 [KSSilencingConfirmSheet alertWithWindow:[[self view] window]
 silencingKey:@"shutUpFakeURL"
 title:NSLocalizedString(@"Non-Page Link",@"title of alert")
 format:NSLocalizedString
 (@"You clicked on a link that would open a page that Sandvox cannot directly display.\n\n\t%@\n\nWhen you publish your website, you will be able to view the page with your browser.", @""),
 [URL path]];
 }
 else
 {
 [[[self windowController] siteOutlineController] setSelectedObjects:[NSArray arrayWithObject:thePage]];
 }
 */