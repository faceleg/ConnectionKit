//
//  KTPageDetailsController.h
//  Marvel
//
//  Created by Mike on 04/01/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class NTBoxView, KSPopUpButton, KTPageDetailsBoxView, MAAttachedWindow;


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
	
@private
	NSNumber	*_metaDescriptionCountdown;
	NSNumber	*_windowTitleCountdown;
	
	NSTextField	*_activeTextField;
	MAAttachedWindow *_attachedWindow;
	
}

- (NTBoxView *)pageDetailsPanel;

// Meta description
- (NSNumber *)metaDescriptionCountdown;
- (NSNumber *)windowTitleCountdown;

@property (retain) NSTextField *activeTextField;
@property (retain) MAAttachedWindow *attachedWindow;

@end
