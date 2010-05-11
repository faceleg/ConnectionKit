//
//  APProductsArrayController.m
//  Amazon List
//
//  Created by Mike on 02/03/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "APProductsArrayController.h"

#import "AmazonListProduct.h"


@implementation APProductsArrayController

#pragma mark -
#pragma mark Drawing

- (void)awakeFromNib
{
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(aProductDidEndLoading:)
												 name:@"AmazonProductDidEndLoading"
											   object:nil];
	
	[super awakeFromNib];
}

- (void)release { [super release]; }

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[super dealloc];
}

/*	If a product we own stops or starts loading, we must manually force
 *	our table view to display the change
 */
- (void)aProductDidEndLoading:(NSNotification *)notification
{
	AmazonListProduct *product = [notification object];
	
	int row = [[self arrangedObjects] indexOfObjectIdenticalTo:product];
	if (row != NSNotFound) {
		[tableView setNeedsDisplayInRect:[tableView rectOfRow:row]];
	}
}

#pragma mark -
#pragma mark Tooltips

- (NSString *)tableView:(NSTableView *)aTableView
		 toolTipForCell:(NSCell *)aCell
				   rect:(NSRectPointer)rect
			tableColumn:(NSTableColumn *)aTableColumn
					row:(int)row
		  mouseLocation:(NSPoint)mouseLocation
{
	AmazonListProduct *product = [[self arrangedObjects] objectAtIndex:row];
	return [product toolTipString];
}

#pragma mark -
#pragma mark Gear menu

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	BOOL result = YES;
	SEL action = [menuItem action];
	
	if (action == @selector(openProductURL:)) {
		result = ([[self selectionIndexes] count] > 0);
	}
	
	return result;
}

// Open the URLs of the selected products
- (IBAction)openProductURL:(id)sender
{
	// Ignore if empty space, not a row, was clicked
	NSArray *selection = [self selectedObjects];
	if (selection)
	{
		AmazonListProduct *product;
		
		for (product in selection)
		{
			NSURL *URL = [product URL];
			if (URL) {
				[[NSWorkspace sharedWorkspace] openURL:URL];
			}
		
		}
	}
}

@end
