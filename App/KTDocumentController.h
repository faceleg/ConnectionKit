//
//  KTDocumentController.h
//  Marvel
//
//  Created by Terrence Talbot on 9/20/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "KSDocumentController.h"


@class KTDocument;


@interface KTDocumentController : KSDocumentController
{
	// New docs
	IBOutlet NSView			*oNewDocAccessoryView;
	IBOutlet NSPopUpButton	*oNewDocHomePageTypePopup;
}

- (IBAction)showDocumentPlaceholderWindow:(id)sender;

@end
