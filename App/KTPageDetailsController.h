//
//  KTPageDetailsController.h
//  Marvel
//
//  Created by Mike on 04/01/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


enum { kUnknownSiteItemType = 0, kLinkSiteItemType, kTextSiteItemType, kFileSiteItemType, kPageSiteItemType, kMixedSiteItemType = -1 };

@class SVPagesController, KSFancySchmancyBindingsPopUpButton, KTPageDetailsBoxView, MAAttachedWindow, KTDocWindowController;


@interface KTPageDetailsController : NSViewController
{
	IBOutlet NSTextField			*oWindowTitleField;
	IBOutlet NSTextField			*oMetaDescriptionField;

	IBOutlet NSTextField			*oWindowTitlePrompt;
	IBOutlet NSTextField			*oMetaDescriptionPrompt;
	IBOutlet NSTextField			*oFilePrompt;

	
	IBOutlet NSTextField			*oBaseURLField;
	IBOutlet NSTextField			*oFileNameField;
	IBOutlet NSTextField			*oDotSeparator;

	IBOutlet NSTextField			*oSlashSeparator;
	IBOutlet NSTextField			*oIndexDotSeparator;
	IBOutlet KSFancySchmancyBindingsPopUpButton			*oExtensionPopup;
	IBOutlet NSTextField			*oMultiplePagesField;

	IBOutlet NSTextField			*oExternalURLField;

	IBOutlet NSButton				*oFollowButton;
	IBOutlet NSButton				*oChooseFileButton;

	IBOutlet SVPagesController		*oPagesController;
	
	IBOutlet NSView					*oAttachedWindowView;
	IBOutlet NSTextField			*oAttachedWindowTextField;
	IBOutlet NSTextField			*oAttachedWindowExplanation;
	IBOutlet NSButton				*oAttachedWindowHelpButton;
	
	IBOutlet KTDocWindowController	*oDocWindowController;	// to communicate with web view
	
@private
	NSNumber	*_metaDescriptionCountdown;
	NSNumber	*_windowTitleCountdown;
	NSNumber	*_fileNameCountdown;
	
	NSTextField	*_activeTextField;
	MAAttachedWindow *_attachedWindow;

	int _whatKindOfItemsAreSelected;
	
	BOOL _alreadyHandlingControlTextDidChange;
	
	NSDictionary *_initialWindowTitleBindingOptions;
	NSDictionary *_initialMetaDescriptionBindingOptions;

	
}

- (IBAction) pageDetailsHelp:(id)sender;
- (IBAction) preview:(id)sender;
- (IBAction) chooseFile:(id)sender;

// Meta description
- (NSNumber *)metaDescriptionCountdown;
- (NSNumber *)windowTitleCountdown;
- (NSNumber *)fileNameCountdown;

@property (retain) 	NSDictionary *initialWindowTitleBindingOptions;
@property (retain) 	NSDictionary *initialMetaDescriptionBindingOptions;

@property (retain) NSTextField *activeTextField;
@property (retain) MAAttachedWindow *attachedWindow;

@property (assign) int whatKindOfItemsAreSelected;

@end
