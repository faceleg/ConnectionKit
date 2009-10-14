//
//  KTPageDetailsController.h
//  Marvel
//
//  Created by Mike on 04/01/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KTDocViewController.h"


@class NTBoxView, KSPopUpButton, KTPageDetailsBoxView;


@interface KTPageDetailsController : KTDocViewController
{
	IBOutlet NSTextField			*oWindowTitleField;
	IBOutlet NSTextField			*oMetaDescriptionField;

	IBOutlet NSTextField			*oPageFileNameField;
	IBOutlet NSTextField			*oCollectionFileNameField;
	IBOutlet KSPopUpButton			*oFileExtensionPopup;
	IBOutlet KSPopUpButton			*oCollectionIndexExtensionButton;
		
	IBOutlet NSObjectController		*oPagesController;
	
@private
	NSNumber	*_metaDescriptionCountdown;
	NSNumber	*_windowTitleCountdown;
}

- (NTBoxView *)pageDetailsPanel;

// Meta description
- (NSNumber *)metaDescriptionCountdown;
- (NSNumber *)windowTitleCountdown;

@end
