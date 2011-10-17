//
//  APInspectorController.m
//  Amazon List
//
//  Created by Mike on 03/02/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import "AmazonListInspector.h"

#import "Sandvox.h"
#import "AmazonSupport.h"

#import "AmazonListPlugIn.h"


@interface AmazonListInspector ()

- (void)initializeStoreSelectionPopupButton;
- (void)prepareTableViews;
- (void)centerLayoutSegmentIcons;

@end


@implementation AmazonListInspector

#pragma mark -
#pragma mark Initialization

- (id)init
{
	[super init];
	return self;
}

- (void)awakeFromNib
{
	[self initializeStoreSelectionPopupButton];
	[self prepareTableViews];
	[self centerLayoutSegmentIcons];
}

- (void)initializeStoreSelectionPopupButton
{
	NSMenu *menu = [storeSelectionPopupButton menu];
	
	[[menu itemWithTag:AmazonStoreUS] setImage:[NSImage flagForAmazonStore:AmazonStoreUS]];
	[[menu itemWithTag:AmazonStoreCanada] setImage:[NSImage flagForAmazonStore:AmazonStoreCanada]];
	[[menu itemWithTag:AmazonStoreUK] setImage:[NSImage flagForAmazonStore:AmazonStoreUK]];
	[[menu itemWithTag:AmazonStoreGermany] setImage:[NSImage flagForAmazonStore:AmazonStoreGermany]];
	[[menu itemWithTag:AmazonStoreFrance] setImage:[NSImage flagForAmazonStore:AmazonStoreFrance]];
	[[menu itemWithTag:AmazonStoreJapan] setImage:[NSImage flagForAmazonStore:AmazonStoreJapan]];
}

- (void)centerLayoutSegmentIcons
{
	int i;
	
	for (i = 0; i < [listLayoutSegmentedControl segmentCount]; i++) {
		[listLayoutSegmentedControl setLabel: nil forSegment: i];
	}
}

#pragma mark Table views

- (void)prepareTableViews
{
	// Sort out double-clicking
	[manualProductsTableView setTarget: [manualProductsTableView dataSource]];
	[manualProductsTableView setDoubleAction: @selector(openProductURL:)];
}

#pragma mark Gear Buttons

- (IBAction)reloadSelectedProduct:(id)sender
{
	NSArray *selectedProducts = [manualProductsArrayController selectedObjects];
	[selectedProducts makeObjectsPerformSelector: @selector(load)];
}

- (IBAction)reloadAllProducts:(id)sender
{
	NSArray *products = [manualProductsArrayController arrangedObjects];
	[products makeObjectsPerformSelector: @selector(load)];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	BOOL result = YES;
	SEL action = [menuItem action];
	
	if (action == @selector(reloadSelectedProduct:))
    {
		result = ([[manualProductsArrayController selectionIndexes] count] > 0);
	}
	else if (action == @selector(reloadAllProducts:))
    {
		result = ([[manualProductsArrayController arrangedObjects] count] > 0);
	}
	
	return result;
}

@end

