//
//  KTPageDetailsController.h
//  Marvel
//
//  Created by Mike on 04/01/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class KSPopUpButton, KTPageDetailsBoxView, MAAttachedWindow;


@interface KTPageDetailsController : NSViewController
{
	IBOutlet NSTextField			*oWindowTitleField;
	IBOutlet NSTextField			*oMetaDescriptionField;

	IBOutlet NSTextField			*oBaseURLField;
	IBOutlet NSTextField			*oPageFileNameField;
	IBOutlet NSTextField			*oDotSeparator;
	IBOutlet KSPopUpButton			*oFileExtensionPopup;
	IBOutlet NSTextField			*oCollectionFileNameField;
	IBOutlet KSPopUpButton			*oCollectionIndexExtensionButton;
		
	IBOutlet NSObjectController		*oPagesController;
	
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
	
}

- (IBAction) pageDetailsHelp:(id)sender;

// Meta description
- (NSNumber *)metaDescriptionCountdown;
- (NSNumber *)windowTitleCountdown;
- (NSNumber *)fileNameCountdown;

@property (retain) NSTextField *activeTextField;
@property (retain) MAAttachedWindow *attachedWindow;

@end
