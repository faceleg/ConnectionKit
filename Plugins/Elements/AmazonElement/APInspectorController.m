//
//  APInspectorController.m
//  Amazon List
//
//  Created by Mike on 03/02/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "APInspectorController.h"

#import "SandvoxPlugin.h"
#import <AmazonSupport/AmazonSupport.h>

#import "AmazonListDelegate.h"
#import "APAmazonProduct.h"
#import "APAmazonList.h"


@interface APInspectorController ()

- (void)initializeStoreSelectionPopupButton;
- (void)prepareTableViews;
- (void)centerLayoutSegmentIcons;
- (void)initializeUnifiedTableButtons;

- (void)observeChangesToListSource;
- (void)stopObservingChangesToListSource;
- (void)listSourceDidChange:(id)newValue;

- (AmazonListDelegate *)pluginDelegate;

- (void)observeChangesToAutomaticListData;
- (void)stopObservingChangesToAutomaticListData;
- (void)populateAutomaticListTableView;
- (void)automaticListDidChangeLoadingStatus;

- (void)updateAutomaticListPlaceholderText;

@end


@implementation APInspectorController

#pragma mark -
#pragma mark Initialization

- (id)init
{
	[super init];
	[self setSelectedTabIdentifier:APProductsOrListTabIdentifier];
	return self;
}

- (void)awakeFromNib
{
	[self initializeStoreSelectionPopupButton];
	[self prepareTableViews];
	[self centerLayoutSegmentIcons];
	[self initializeUnifiedTableButtons];
	
	[self observeChangesToListSource];
	[self observeChangesToAutomaticListData];
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

- (void)initializeUnifiedTableButtons
{
	// Set up the boxes under the tables
	[manualTableViewButtonsBox setDrawsFrame: YES];
	[manualTableViewButtonsBox setFill: NTBoxBevel];
	[manualTableViewButtonsBox setBorderMask: (NTBoxLeft | NTBoxRight | NTBoxBottom)];
	[manualTableViewButtonsBox setFrameColor: [NSColor lightGrayColor]];
	
	[automaticTableButtonsBox setDrawsFrame: YES];
	[automaticTableButtonsBox setFill: NTBoxBevel];
	[automaticTableButtonsBox setBorderMask: (NTBoxLeft | NTBoxRight | NTBoxBottom)];
	[automaticTableButtonsBox setFrameColor: [NSColor lightGrayColor]];
	
	// Give the buttons their icons
	[oManualListAddProductButton setImage:[NSImage addToTableButtonIcon]];
	[oManualListRemoveProductButton setImage:[NSImage removeFromTableButtonIcon]];
}

#pragma mark -
#pragma mark Dealloc

- (void)dealloc
{
	[self stopObservingChangesToListSource];
	[self stopObservingChangesToAutomaticListData];
	
	[mySelectedTab release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
					    change:(NSDictionary *)change
					   context:(void *)context
{
	if (object == pluginController)
	{
		if ([keyPath isEqualToString:@"selection.delegate.automaticListCode"]) {
			[self updateAutomaticListPlaceholderText];
		}
		else if ([keyPath isEqualToString:@"selection.listSource"]) {
			[self listSourceDidChange:[object valueForKeyPath:keyPath]];
		}
		else if ([keyPath isEqualToString:@"selection.maxNumberProducts"] ||
				 [keyPath isEqualToString:@"selection.delegate.automaticList.products"]) {
			[self populateAutomaticListTableView];
		}
		else if ([keyPath isEqualToString:@"selection.delegate.automaticList.loadingData"]) {
			[self automaticListDidChangeLoadingStatus];
		}
	}
}

#pragma mark -
#pragma mark Convenience Methods

- (AmazonListDelegate *)pluginDelegate
{
	return [[pluginController content] delegate];
}

#pragma mark -
#pragma mark TabView

#pragma mark Selected tab

- (NSString *)selectedTabIdentifier { return mySelectedTab; }

- (void)setSelectedTabIdentifier:(NSString *)identifier
{
	identifier = [identifier copy];
	[mySelectedTab release];
	mySelectedTab = identifier;
}

- (void)observeChangesToListSource
{
	[pluginController addObserver:self forKeyPath:@"selection.listSource" options:0 context:nil];
	
	// We must retain the tab view items so that they are not deallocated when removed from the tab view
	[productsTabViewItem retain];
	[listTabViewItem retain];
}

- (void)stopObservingChangesToListSource
{
	[pluginController removeObserver:self forKeyPath:@"selection.listSource"];
	
	[productsTabViewItem release];
	[listTabViewItem release];
}

- (void)listSourceDidChange:(id)newValue
{
	// Add and remove the appropriate tab view items
	
	///	This new check of the value's class is to handle closing the document. What happens is we get a
	/// _NSStateMarker rather than an NSNumber since there is no longer anything connected to the
	/// plugin controller.
	
	if ([newValue isKindOfClass:[NSNumber class]])
	{
		AmazonPageletListSource newSource = [newValue intValue];
		NSString *itemIdentifier = [[tabView selectedTabViewItem] identifier];
		
		switch (newSource)
		{
			case AmazonPageletPickByHand:
				[tabView removeTabViewItem:listTabViewItem];
				[tabView insertTabViewItemIfNotAlreadyPresent:productsTabViewItem atIndex:0];
				break;
				
			case AmazonPageletLoadFromList:
				[tabView removeTabViewItem:productsTabViewItem];
				[tabView insertTabViewItemIfNotAlreadyPresent:listTabViewItem atIndex:0];
				break;
		}
		
		[tabView selectTabViewItemWithIdentifier:itemIdentifier];
	}
}

#pragma mark -
#pragma mark Table views

- (void)prepareTableViews
{
	// Sort out double-clicking
	[manualProductsTableView setTarget: [manualProductsTableView dataSource]];
	[manualProductsTableView setDoubleAction: @selector(openProductURL:)];
	
	[automaticListTableView setTarget: [automaticListTableView dataSource]];
	[automaticListTableView setDoubleAction: @selector(openProductURL:)];
	
	// disable drag and drop in the automatic list
	[[automaticListTableView dataSource] setAllowsDragAndDropTableReordering:NO];
}

- (void)observeChangesToAutomaticListData
{
	[pluginController addObserver:self
					   forKeyPath:@"selection.delegate.automaticListCode"
					      options:0
						  context:nil];
	
	[pluginController addObserver:self
					   forKeyPath:@"selection.maxNumberProducts"
					      options:0
						  context:nil];
	
	[pluginController addObserver:self
					   forKeyPath:@"selection.delegate.automaticList.products"
					      options:0
						  context:nil];
	
	[pluginController addObserver:self
					   forKeyPath:@"selection.delegate.automaticList.loadingData"
					      options:0
						  context:nil];
}

- (void)stopObservingChangesToAutomaticListData
{
	[pluginController removeObserver:self forKeyPath:@"selection.delegate.automaticListCode"];
	[pluginController removeObserver:self forKeyPath:@"selection.maxNumberProducts"];
	[pluginController removeObserver:self forKeyPath:@"selection.delegate.automaticList.products"];
	[pluginController removeObserver:self forKeyPath:@"selection.delegate.automaticList.loadingData"];
}

- (void)populateAutomaticListTableView
{
	id pluginDelegate = [self pluginDelegate];
	
	NSArray *allProducts = [[pluginDelegate automaticList] products];
	if (allProducts && ![allProducts isEmpty])
	{
		// Build the range as appropriate
		NSRange productsRange;
		unsigned maxNumberProducts = [[pluginDelegate delegateOwner] integerForKey:@"maxNumberProducts"];
		
		if ([allProducts count] < maxNumberProducts || maxNumberProducts == 0) {
			productsRange = NSMakeRange(0, [allProducts count]);
		}
		else {
			productsRange = NSMakeRange(0, maxNumberProducts);
		}
		
		[pluginDelegate setAutomaticListProductsToDisplay: [allProducts subarrayWithRange:productsRange]];
	}
	else
	{
		[pluginDelegate setAutomaticListProductsToDisplay:nil];
	}
}

- (void)automaticListDidChangeLoadingStatus
{
	BOOL loading = NO;
	id value = [pluginController valueForKeyPath:@"selection.delegate.automaticList.loadingData"];
	
	if ([value isKindOfClass:[NSNumber class]]) {
		loading = [value boolValue];
	}
	
	[automaticListTableView setLoadingData:loading];
	
	[self updateAutomaticListPlaceholderText];
}

- (void)updateAutomaticListPlaceholderText
{
	id pluginDelegate = [self pluginDelegate];
	NSString *listCode = [[pluginDelegate delegateOwner] valueForKey:@"automaticListCode"];
	BOOL listLoading = [[pluginDelegate automaticList] isLoadingData];
	NSArray *products = [pluginDelegate automaticListProductsToDisplay];
	
	
	[automaticListTableView setPlaceholderStringColor:[NSColor grayColor]];	// Grey is the default
	
	if (!listCode || [listCode isEqualToString:@""]) {	// Remind the user what to do
		[automaticListTableView setPlaceholderString:LocalizedStringInThisBundle(@"Please enter the ID or public URL of an Amazon list above", "Table placeholder text")];
	}
	else if (listLoading || (products && [products count] > 0))	{ // Nothing to display once loaded or loading
		[automaticListTableView setPlaceholderString:nil];
	}
	else	// This lot are errors (in red!)
	{
		[automaticListTableView setPlaceholderStringColor:[NSColor redColor]];
		
		NSError *error = [[pluginDelegate automaticList] lastLoadError];
		NSURL *URL = [NSURL URLWithString:listCode];
		
		if (error && [[error domain] isEqualToString:NSURLErrorDomain] && [error code] == -1009) { // No internet connection
			[automaticListTableView setPlaceholderString:LocalizedStringInThisBundle(@"No Internet connection", "table cell")];
		}
		else if (URL && [URL hasNetworkLocation]) {	// The user entered an invalid URL
			[automaticListTableView setPlaceholderString:LocalizedStringInThisBundle(@"The URL entered does not appear to be a public Amazon list URL", "error message in tableview")];
		}
		else if (!products || [products count] == 0) {	// Nothing found
			[automaticListTableView setPlaceholderString:LocalizedStringInThisBundle(@"No list with that ID was found", "error message in tableview")];
		}
		else {	// Fallback onto general "error"
			[automaticListTableView setPlaceholderString:LocalizedStringInThisBundle(@"There was an error loading the list.", "error message in tableview")];
		}
	}
}

#pragma mark -
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
	
	if (action == @selector(reloadSelectedProduct:)) {
		result = ([[manualProductsArrayController selectionIndexes] count] > 0);
	}
	else if (action == @selector(reloadAllProducts:)) {
		result = ([[manualProductsArrayController arrangedObjects] count] > 0);
	}
	else if (action == @selector(openListURL:)) {
		result = ([[[self pluginDelegate] automaticList] listURL] != nil);
	}
	
	return result;
}

- (IBAction)reloadList:(id)sender
{
	[[self pluginDelegate] loadAutomaticList];
}

- (IBAction)openListURL:(id)sender
{
	NSURL *URL = [[[self pluginDelegate] automaticList] listURL];
	if (URL) {
		[[NSWorkspace sharedWorkspace] openURL: URL];
	}
}

@end


#pragma mark -


@implementation NSTabView (APInspectorController)

- (void)insertTabViewItemIfNotAlreadyPresent:(NSTabViewItem *)tabViewItem atIndex:(unsigned)index;
{
	if (![[self tabViewItems] containsObjectIdenticalTo:tabViewItem]) {
		[self insertTabViewItem:tabViewItem atIndex:index];
	}
}

@end

