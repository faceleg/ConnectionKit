//
//  APInspectorController.h
//  Amazon List
//
//  Created by Mike on 03/02/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//
//	Controls the Inspector interface of the pagelet. Its function is
//	to ensure the Inspector looks right to the user and to kick off loading of the
//	automatic list as required. All the "heavy lifting" is passed onto
//	AmazonListDelegate to handle


#import <Cocoa/Cocoa.h>
#import "SandvoxPlugin.h"


@class NTBoxView;


@interface APInspectorController : SVInspectorViewController
{
	IBOutlet NSPopUpButton		*storeSelectionPopupButton;
	IBOutlet NSObjectController	*pluginController;
	
	IBOutlet NSTabView		*tabView;
	IBOutlet NSTabViewItem	*productsTabViewItem;
	IBOutlet NSTabViewItem	*listTabViewItem;
	
	IBOutlet NSTableView		*manualProductsTableView;
	IBOutlet NTBoxView			*manualTableViewButtonsBox;
	IBOutlet NSButton			*oManualListAddProductButton;
	IBOutlet NSButton			*oManualListRemoveProductButton;
	IBOutlet NSArrayController	*manualProductsArrayController;
	
	IBOutlet KSPlaceholderTableView	*automaticListTableView;
	IBOutlet NTBoxView				*automaticTableButtonsBox;
	
	IBOutlet NSSegmentedControl	*listLayoutSegmentedControl;
	
	
	@private
	NSString	*mySelectedTab;
}

- (NSString *)selectedTabIdentifier;
- (void)setSelectedTabIdentifier:(NSString *)identifier;

- (IBAction)reloadSelectedProduct:(id)sender;
- (IBAction)reloadAllProducts:(id)sender;

- (IBAction)reloadList:(id)sender;
- (IBAction)openListURL:(id)sender;

@end


@interface NSTabView (APInspectorController)
- (void)insertTabViewItemIfNotAlreadyPresent:(NSTabViewItem *)tabViewItem atIndex:(unsigned)index;
@end