//
//  KTPluginInstallerController.h
//  Marvel
//
//  Created by Dan Wood on 1/29/08.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class URLStackManager;

@interface KTPluginInstallerController : NSWindowController {

	float myScaleFactor;
	NSArray *myPlugins;
	IBOutlet NSTableView *oTable;
	IBOutlet NSArrayController *oArrayController;
	IBOutlet 
	BOOL myShowOnlyUpdates;
	NSString *prompt;
	NSColor *promptColor;
	int myCheckedCount;
	NSString *buttonTitle;
	NSMutableArray *myLoaders;
	NSMutableString *myErrorString;
}

- (NSArray *)pluginsNeedingUpdate;		// returns a list of plugins that need updating; if not empty then we should show the window.

- (NSMutableArray *)loaders;
- (void)setLoaders:(NSMutableArray *)aLoaders;

- (NSMutableString *)errorString;
- (void)setErrorString:(NSMutableString *)anErrorString;

- (NSArray *)plugins;
- (void)setPlugins:(NSArray *)aPlugins;

- (NSString *)buttonTitle;
- (void)setButtonTitle:(NSString *)aButtonTitle;

- (BOOL)showOnlyUpdates;
- (void)setShowOnlyUpdates:(BOOL)flag;

- (NSString *)prompt;
- (void)setPrompt:(NSString *)aPrompt;
- (NSColor *)promptColor;
- (void)setPromptColor:(NSColor *)aPromptColor;
- (int)checkedCount;
- (void)setCheckedCount:(int)aCheckedCount;

- (IBAction)showWindowForNewVersions:(id)sender;
- (IBAction) downloadSelectedPlugins:(id)sender;

+ (KTPluginInstallerController *)sharedController;
+ (KTPluginInstallerController *)sharedControllerWithoutLoading;

- (void) prepareForDisplay;

// Icon at:  /System/Library/CoreServices/Software Update.app/Contents/Resources/Software Update.icns

@end
