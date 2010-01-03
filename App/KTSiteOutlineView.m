//
//  KTSiteOutlineView.m
//  Marvel
//
//  Created by Terrence Talbot on 11/29/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "KTSiteOutlineView.h"

#import "KT.h"
#import "KTDocWindowController.h"
#import "KTPage.h"
#import "KTPulsatingOverlay.h"
#import "NSOutlineView+KTExtensions.h"
#import "KTAbstractPluginDelegate.h"

#import "Registration.h"


NSString *kKTSelectedObjectsKey = @"KTSelectedObjects";
NSString *kKTSelectedObjectsClassNameKey = @"KTSelectedObjectsClassName";


@implementation KTSiteOutlineView

- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation
{
	[super draggedImage:anImage endedAt:aPoint operation:operation];
	
	// check for drag to Trash
	if ( operation == NSDragOperationDelete )
	{
		// delete any pages on the drag pboard
		NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
		NSArray *supportedTypes = [NSArray arrayWithObject:kKTOutlineDraggingPboardType];
		NSString *bestType = [pboard availableTypeFromArray:supportedTypes];
		
		if ( [bestType isEqual:kKTOutlineDraggingPboardType] )
		{
			//FIXME: Delete the pages
		}
	}
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
	[[KTPulsatingOverlay sharedOverlay] hide];
	[super draggingExited:sender];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
	NSPoint point = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	int row = [self rowAtPoint:point];
	id item = [self itemAtRow:row];
	
	if ( [item isKindOfClass:[KTPage class]] )
	{				
		// first, establish context and selection
		NSMutableDictionary *context = [NSMutableDictionary dictionary];
		[context setObject:[KTPage className] forKey:kKTSelectedObjectsClassNameKey];
		
		// compare selectedItems against item clicked
		NSMutableArray *selectedItems = [[[self selectedItems] mutableCopy] autorelease];
		if ( ![selectedItems containsObject:item] )
		{
			// item is not in selectedItems, select only item and just put that in context
			[context setObject:[NSArray arrayWithObject:item] forKey:kKTSelectedObjectsKey];
			[self selectItem:item];
		}
		else
		{
			[context setObject:selectedItems forKey:kKTSelectedObjectsKey];
		}
		
		// now, build menu
		NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Site Outline Contextual Menu"];
		
		// Cut
		NSMenuItem *cutMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Cut", "Cut MenuItem")
															 action:@selector(cutViaContextualMenu:)
													  keyEquivalent:@""];
		[cutMenuItem setRepresentedObject:context];
		[cutMenuItem setTarget:nil];
		[menu addItem:cutMenuItem];
		[cutMenuItem release];
		
		// Copy
		NSMenuItem *copyMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Copy", "Copy MenuItem")
															  action:@selector(copyViaContextualMenu:)
													   keyEquivalent:@""];
		[copyMenuItem setRepresentedObject:context];
		[copyMenuItem setTarget:nil];
		[menu addItem:copyMenuItem];
		[copyMenuItem release];
		
		// Paste
		NSMenuItem *pasteMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Paste", "Paste MenuItem")
															   action:@selector(pasteViaContextualMenu:)
														keyEquivalent:@""];
		[pasteMenuItem setRepresentedObject:context];
		[pasteMenuItem setTarget:nil];
		[menu addItem:pasteMenuItem];
		[pasteMenuItem release];
		
		// Delete
		NSMenuItem *deleteMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Delete", "Delete MenuItem")
																action:@selector(deleteViaContextualMenu:)
														 keyEquivalent:@""];
		[deleteMenuItem setRepresentedObject:context];
		[deleteMenuItem setTarget:nil];
		[menu addItem:deleteMenuItem];
		[deleteMenuItem release];
		
		// --
		[menu addItem:[NSMenuItem separatorItem]];
		
		// Duplicate
		NSMenuItem *duplicateMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Duplicate", "Duplicate MenuItem")
																   action:@selector(duplicateViaContextualMenu:)
															keyEquivalent:@""];
		[duplicateMenuItem setRepresentedObject:context];
		[duplicateMenuItem setTarget:nil];
		[menu addItem:duplicateMenuItem];
		[duplicateMenuItem release];
		
		// add Edit Raw HTML...
		if ( ((nil == gRegistrationString) || gIsPro) 
			 && [[[[(KTPage *)item plugin] bundle] bundleIdentifier] isEqualToString:@"sandvox.HTMLElement"] )
		{
			// --
			[menu addItem:[NSMenuItem separatorItem]];
			
			NSString *title = NSLocalizedString(@"Edit Raw HTML...", "Edit Raw HTML... MenuItem");
			NSMenuItem *editRawHTMLItem = [[NSMenuItem alloc] initWithTitle:title
																	 action:@selector(editRawHTMLInSelectedBlock:) 
															  keyEquivalent:@""];
			if ( nil == gRegistrationString )
			{
				[[NSApp delegate] setMenuItemPro:editRawHTMLItem];
			}
			[editRawHTMLItem setRepresentedObject:nil];
			[editRawHTMLItem setTarget:nil];
			[menu addItem:editRawHTMLItem];
			[editRawHTMLItem release];
		}
		
		return [menu autorelease];
	}
    
    // default is just to return super's implementation
	NSMenu *standardMenu = [super menuForEvent:theEvent];
    return standardMenu;
}

#pragma mark -
#pragma mark Reloading

// via http://www.corbinstreehouse.com/blog/?p=151
- (void)reloadData
{
	if ( !_isReloadingData )
	{
		_isReloadingData = YES;
		[super reloadData];
		_isReloadingData = NO;
	}
	else
	{
		[self performSelector:@selector(reloadData) withObject:nil afterDelay:0.0];
	}
}

@end
