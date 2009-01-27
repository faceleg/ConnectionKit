//
//  KTPageDetailsController.h
//  Marvel
//
//  Created by Mike on 04/01/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KTDocViewController.h"


@class NTBoxView, KSPopUpButton;


@interface KTPageDetailsController : KTDocViewController
{
	IBOutlet NSTextField			*oPageFileNameField;
	IBOutlet NSTextField			*oCollectionFileNameField;
	IBOutlet NSTokenField			*oKeywordsField;
	IBOutlet KSPopUpButton			*oFileExtensionPopup;
	IBOutlet KSPopUpButton			*oCollectionIndexExtensionButton;
	
	IBOutlet NSObjectController	*oPagesController;
	
@private
	NSNumber	*_metaDescriptionCountdown;
}

- (NTBoxView *)pageDetailsPanel;

// Meta description
- (NSNumber *)metaDescriptionCountdown;

@end
