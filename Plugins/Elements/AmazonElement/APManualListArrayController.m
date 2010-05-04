//
//  APManualListArrayController.m
//  Amazon List
//
//  Created by Mike on 22/01/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "APManualListArrayController.h"

#import "AmazonListPlugIn.h"
#import "APManualListProduct.h"

#import <AmazonSupport/AmazonSupport.h>

#import "NSURL+AmazonPagelet.h"


@implementation APManualListArrayController

#pragma mark -
#pragma mark Init & Dealloc

- (void)awakeFromNib
{
	[super awakeFromNib];
	
	NSString *placeholder = LocalizedStringInThisBundle(@"Drag Amazon products here from your web browser",
														@"Appears in an empty tableview");
	[(KSPlaceholderTableView *)tableView setPlaceholderString: placeholder];
}

#pragma mark -
#pragma mark New Object

- (id)newObject
{
	APManualListProduct *product = [[APManualListProduct alloc] init];
	[product setStore:[[pluginController content] integerForKey:@"store"]];
	
	// Attempt to get the product ASIN from Safari
	NSURL *URL = nil;
	[NSAppleScript getWebBrowserURL: &URL title: NULL source: NULL];
	
	if ([URL amazonProductASIN])
	{
		NSString *code = [URL absoluteString];
		[product validateValue:&code forKey:@"productCode" error:NULL];
		[product setProductCode:code];	/// No need to load here, the delegate will do it
	}
	
	return product;
}

#pragma mark -
#pragma mark Dragging

- (NSArray *)URLDragTypes { return SVWebLocationGetReadablePasteboardTypes(nil); }

- (NSArray *)dragTypesToRegister
{
	return [[super dragTypesToRegister] arrayByAddingObjectsFromArray:[self URLDragTypes]];
}

- (id)valueForDropFromPasteboard:(NSPasteboard *)pasteboard
{
	// Retrieve the appropriate URL from the pasteboard
	NSArray *webLocations = [NSClassFromString(@"KSWebLocation") webLocationsFromPasteboard:pasteboard readWeblocFiles:YES ignoreFileURLs:YES];
	
	return [[webLocations firstObjectKS] URL];
}

- (NSDragOperation)tableView:(NSTableView *)aTableView	
				validateDrop:(id <NSDraggingInfo>)info
				 proposedRow:(int)row
	   proposedDropOperation:(NSTableViewDropOperation)operation
{
	NSDragOperation result = [super tableView: aTableView
								 validateDrop: info
								  proposedRow: row
						proposedDropOperation: operation];
	
	// If copying the source, see if it is valid
	if (result == NSDragOperationCopy)
	{
		NSPasteboard *pasteboard = [info draggingPasteboard];
		id dropValue = [self valueForDropFromPasteboard: pasteboard];
		if (!dropValue) {
			result = NSDragOperationNone;
		}
	}
	
	return result;
}

- (BOOL)tableView:(NSTableView*)table
	   acceptDrop:(id <NSDraggingInfo>)info
			  row:(int)row
	dropOperation:(NSTableViewDropOperation)op
{
	// See if our superclass will handle the drop
	BOOL result = [super tableView: table acceptDrop: info row: row dropOperation: op];
	if (result) {
		return YES;
	}
	
	
	// Retrieve the appropriate URL from the pasteboard
	NSPasteboard *pasteboard = [info draggingPasteboard];
	NSURL *URL = [self valueForDropFromPasteboard: pasteboard];
	
	
	// If a URL was found, create a new product from it
	if (URL)
	{
		APManualListProduct *product = [[APManualListProduct alloc] init];
		
		// convert into a valid code
		NSString *code = [URL absoluteString];
		[product validateValue:&code forKey:@"productCode" error:NULL];
		[product setProductCode:code];

		[product setStore:[[pluginController content] /* a KTPagelet */ integerForKey:@"store"]];
		
		if (row == -1) {
			row = 0;
		}
		[self insertObject: product atArrangedObjectIndex: row];
		
		[product release];
	}
	
	
	return (URL != nil);
}

@end
