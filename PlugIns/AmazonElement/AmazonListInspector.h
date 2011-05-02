//
//  APInspectorController.h
//  Amazon List
//
//  Created by Mike on 03/02/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//
//	Controls the Inspector interface of the pagelet. Its function is
//	to ensure the Inspector looks right to the user and to kick off loading of the
//	automatic list as required. All the "heavy lifting" is passed onto
//	AmazonListDelegate to handle


#import <Cocoa/Cocoa.h>
#import "Sandvox.h"


@class NTBoxView;


@interface AmazonListInspector : SVInspectorViewController
{
	IBOutlet NSPopUpButton		*storeSelectionPopupButton;
	
	IBOutlet NSTabView		*tabView;
	IBOutlet NSTabViewItem	*productsTabViewItem;
	IBOutlet NSTabViewItem	*listTabViewItem;
	
	IBOutlet NSTableView		*manualProductsTableView;
	IBOutlet NTBoxView			*manualTableViewButtonsBox;
	IBOutlet NSButton			*oManualListAddProductButton;
	IBOutlet NSButton			*oManualListRemoveProductButton;
	IBOutlet NSArrayController	*manualProductsArrayController;
		
	IBOutlet NSSegmentedControl	*listLayoutSegmentedControl;
}

- (IBAction)reloadSelectedProduct:(id)sender;
- (IBAction)reloadAllProducts:(id)sender;

@end