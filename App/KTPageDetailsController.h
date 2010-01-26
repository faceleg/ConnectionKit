//
//  KTPageDetailsController.h
//  Marvel
//
//  Created by Mike on 04/01/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


enum { kUnknownSiteItemType = 0, kLinkSiteItemType = 1, kPageSiteItemType = 2, kMixedSiteItemType = 3 };

@class SVPagesController, KSPopUpButton, KTPageDetailsBoxView, MAAttachedWindow;


@interface KTPageDetailsController : NSViewController
{
	IBOutlet NSTextField			*oWindowTitleField;
	IBOutlet NSTextField			*oMetaDescriptionField;

	IBOutlet NSTextField			*oWindowTitlePrompt;
	IBOutlet NSTextField			*oMetaDescriptionPrompt;

	
	IBOutlet NSTextField			*oBaseURLField;
	IBOutlet NSTextField			*oPageFileNameField;
	IBOutlet NSTextField			*oDotSeparator;

	IBOutlet NSTextField			*oSlashIndexDotSeparator;
	IBOutlet NSTextField			*oIndexDotSeparator;
	IBOutlet KSPopUpButton			*oExtensionPopup;
	IBOutlet NSTextField			*oCollectionFileNameField;

	IBOutlet NSTextField			*oExternalURLField;
	IBOutlet NSTextField			*oOtherFileNameField;

	IBOutlet NSButton				*oFollowButton;

	IBOutlet SVPagesController		*oPagesController;
	
	IBOutlet NSView					*oAttachedWindowView;
	IBOutlet NSTextField			*oAttachedWindowTextField;
	IBOutlet NSTextField			*oAttachedWindowExplanation;
	IBOutlet NSButton				*oAttachedWindowHelpButton;
	
@private
	NSNumber	*_metaDescriptionCountdown;
	NSNumber	*_windowTitleCountdown;
	NSNumber	*_fileNameCountdown;
	
	NSTextField	*_activeTextField;
	MAAttachedWindow *_attachedWindow;

	int _whatKindOfItemsAreSelected;
	
	BOOL _alreadyHandlingControlTextDidChange;
	
}

- (IBAction) pageDetailsHelp:(id)sender;
- (IBAction) preview:(id)sender;

// Meta description
- (NSNumber *)metaDescriptionCountdown;
- (NSNumber *)windowTitleCountdown;
- (NSNumber *)fileNameCountdown;

@property (retain) NSTextField *activeTextField;
@property (retain) MAAttachedWindow *attachedWindow;

@property (assign) int whatKindOfItemsAreSelected;

@end
