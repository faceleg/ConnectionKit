//
//  KTPageDetailsController.h
//  Marvel
//
//  Created by Mike on 04/01/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <BWToolkitFramework/BWToolkitFramework.h>


enum { kUnknownSiteItemType = 0, kLinkSiteItemType, kTextSiteItemType, kFileSiteItemType, kPageSiteItemType, kMixedSiteItemType = -1 };

@class SVSiteOutlineViewController, SVPagesTreeController, KSFancySchmancyBindingsPopUpButton, KTPageDetailsBoxView, MAAttachedWindow, SVWebContentAreaController, KSFocusingTextField;


@interface KTPageDetailsController : NSViewController <NSWindowDelegate>
{
	IBOutlet KSFocusingTextField	*oWindowTitleField;
	IBOutlet KSFocusingTextField	*oMetaDescriptionField;
	IBOutlet KSFocusingTextField	*oExternalURLField;
	IBOutlet KSFocusingTextField	*oFileNameField;		// binds to fileName
	IBOutlet KSFocusingTextField	*oMediaFilenameField;	// binds to filename

	IBOutlet NSTextField			*oWindowTitlePrompt;
	IBOutlet NSTextField			*oMetaDescriptionPrompt;
	IBOutlet NSTextField			*oFilePrompt;

	
	IBOutlet NSTextField			*oBaseURLField;
	IBOutlet NSTextField			*oDotSeparator;

	IBOutlet NSTextField			*oSlashSeparator;
	IBOutlet NSPopUpButton			*oExtensionPopup;
	IBOutlet NSPopUpButton			*oIndexAndExtensionPopup;
	IBOutlet NSTextField			*oMultiplePagesField;


	IBOutlet NSButton				*oFollowButton;
	IBOutlet NSButton				*oChooseFileButton;
	IBOutlet NSButton				*oEditTextButton;

    IBOutlet SVSiteOutlineViewController *oSiteOutlineController;
	IBOutlet SVPagesTreeController	*oPagesTreeController;
    
	IBOutlet BWIWorkPopUpButton		*oPublishAsCollectionPopup;

	IBOutlet NSView					*oAttachedWindowView;
	IBOutlet NSTextField			*oAttachedWindowTextField;
	IBOutlet NSTextField			*oAttachedWindowExplanation;
	IBOutlet NSButton				*oAttachedWindowHelpButton;
		
@private
    SVWebContentAreaController  *_contentArea;
    
	NSNumber	*_metaDescriptionCount;
	NSNumber	*_windowTitleCount;
	NSNumber	*_fileNameCount;
	
	NSTextField	*_activeTextField;
	MAAttachedWindow *_attachedWindow;

	int     _whatKindOfItemsAreSelected;
	int		_maxFileCharacters;
	
	BOOL _alreadyHandlingControlTextDidChange;
	
	NSDictionary *_initialWindowTitleBindingOptions;
	NSDictionary *_initialMetaDescriptionBindingOptions;

	BOOL _awokenFromNib;
	
	NSTrackingArea *_windowTitleTrackingArea;
	NSTrackingArea *_metaDescriptionTrackingArea;
	NSTrackingArea *_externalURLTrackingArea;
	NSTrackingArea *_fileNameTrackingArea;
	NSTrackingArea *_mediaFilenameTrackingArea;
	
}

@property (nonatomic, retain) NSTrackingArea *windowTitleTrackingArea;
@property (nonatomic, retain) NSTrackingArea *metaDescriptionTrackingArea;
@property (nonatomic, retain) NSTrackingArea *externalURLTrackingArea;
@property (nonatomic, retain) NSTrackingArea *fileNameTrackingArea;
@property (nonatomic, retain) NSTrackingArea *mediaFilenameTrackingArea;

@property(nonatomic, retain) IBOutlet SVWebContentAreaController *webContentAreaController;

- (IBAction) pageDetailsHelp:(id)sender;
- (IBAction) preview:(id)sender;
- (IBAction) chooseFile:(id)sender;


// Publish as Collection
- (IBAction)popupSetPageOrCollection:(NSButton *)sender;


// Meta description
- (NSNumber *)metaDescriptionCount;
- (NSNumber *)windowTitleCount;
- (NSNumber *)fileNameCount;

@property (nonatomic, retain) 	NSDictionary *initialWindowTitleBindingOptions;
@property (nonatomic, retain) 	NSDictionary *initialMetaDescriptionBindingOptions;

@property (nonatomic, retain) NSTextField *activeTextField;
@property (nonatomic, retain) MAAttachedWindow *attachedWindow;

@property (nonatomic, assign) int whatKindOfItemsAreSelected;

@end
