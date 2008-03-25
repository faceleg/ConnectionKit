//
//  KTDocWindowController+Toolbar.m
//  Marvel
//
//  Copyright (c) 2004-2005 Biophony, LLC. All rights reserved.
//

/*
PURPOSE OF THIS CLASS/CATEGORY:
	Manage document's toolbar

TAXONOMY AND RELATIONSHIP TO OTHER CLASSES:
	x

IMPLEMENTATION NOTES & CAUTIONS:
	x

TO DO:
	x

 */

#import "KTDocWindowController.h"

#import "Debug.h"
#import "KT.h"
#import "KTAppDelegate.h"
#import "KTDocument.h"
#import "KTElementPlugin.h"
#import "KTIndexPlugin.h"
#import "KTToolbars.h"
#import "NSImage+KTExtensions.h"
#import "NSImage+Karelia.h"
#import "NSToolbar+Karelia.h"
#import "RYZImagePopUpButton.h"
#import "RYZImagePopUpButtonCell.h"

@interface KTDocWindowController ( PrivateToolbar )

- (NSToolbar *)toolbarNamed:(NSString *)toolbarName;

@end

// NB: there's about two-thirds the work here to make this a separate controller for BiophonyAppKit
//  it needs a way to define views that aren't app specific, should all be doable via xml
//  for "standard" controls, like an RYZImagePopUpButton

@implementation KTDocWindowController ( Toolbar )

- (void)makeDocumentToolbar
{
    NSToolbar *toolbar = [self toolbarNamed:@"document"];

    [toolbar setAllowsUserCustomization:YES];
    [toolbar setAutosavesConfiguration:YES];
    [toolbar setDisplayMode:NSToolbarDisplayModeDefault];
    [toolbar setDelegate:self];

    [[self window] setToolbar:toolbar];
	[self updateToolbar];		// get the states right
}


- (void)updateToolbar
{
	NSToolbar *toolbar = [[self window] toolbar];
	NSToolbarItem *toolbarItem = [toolbar itemWithIdentifier:@"toggleEditingControlsShown:"];
	BOOL displayEditing = [[self document] displayEditingControls];
	if (displayEditing)
	{
		[toolbarItem setLabel:TOOLBAR_EDIT_OFF];
		[toolbarItem setToolTip:TOOLTIP_EDIT_OFF];
		NSImage *theImage = [NSImage imageNamed:@"toolbar_edit_off"];
		[theImage normalizeSize];
		[theImage setDataRetained:YES];	// allow image to be scaled.
		[toolbarItem setImage:theImage];
	}
	else
	{
		[toolbarItem setLabel:TOOLBAR_EDIT_ON];
		[toolbarItem setToolTip:TOOLTIP_EDIT_ON];
		NSImage *theImage = [NSImage imageNamed:@"toolbar_edit_on"];
		[theImage normalizeSize];
		[theImage setDataRetained:YES];	// allow image to be scaled.
		[toolbarItem setImage:theImage];
	}
}


- (NSToolbar *)toolbarNamed:(NSString *)toolbarName
{
    NSString *path = [[NSBundle mainBundle] pathForResource:toolbarName ofType:@"toolbar"];

    if ( nil != path ) 
	{
        NSMutableDictionary *toolbarInfo = [NSMutableDictionary dictionaryWithContentsOfFile:path];
        if ( nil != toolbarInfo ) 
		{
            NSString *toolbarIdentifier = [toolbarInfo valueForKey:@"toolbar name"];
            if ( nil != toolbarIdentifier ) 
			{
                NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:toolbarIdentifier] autorelease];
                NSMutableDictionary *toolbarsEntry = [NSMutableDictionary dictionary];

                [toolbarsEntry setObject:toolbar forKey:@"toolbar"];
                [toolbarsEntry setObject:toolbarInfo forKey:@"info"];
                [[self toolbars] setObject:toolbarsEntry forKey:toolbarIdentifier];

                return toolbar;
            }
            else 
			{
                LOG((@"KTDocWindowController: unable to find key 'toolbar name' for toolbar: %@", toolbarName));
            }
        }
        else 
		{
            LOG((@"KTDocWindowController: unable to read configuration for toolbar at path: %@\nError in plist?", path));
        }
    }
    else 
	{
        LOG((@"KTDocWindowController: unable to locate toolbar: %@", toolbarName));
    }

    return nil;
}

- (NSMutableDictionary *)infoForToolbar:(NSToolbar *)toolbar
{
    // walk the toolbars looking for the toolbar
    NSEnumerator *enumerator = [myToolbars objectEnumerator];
    NSDictionary *toolbarEntry;

    while ( toolbarEntry = [enumerator nextObject] ) 
	{
        if ( [toolbarEntry objectForKey:@"toolbar"] == toolbar ) 
		{
            return [toolbarEntry objectForKey:@"info"];
        }
    }

    return nil;
}

#pragma mark Delegate (NSToolbar)

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString*)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];

    NSArray *itemsArray = [[self infoForToolbar:toolbar] objectForKey:@"item array"];
    NSEnumerator *enumerator = [itemsArray objectEnumerator];
    NSDictionary *itemInfo;

    while ( itemInfo = [enumerator nextObject] ) 
	{
        if ( [[itemInfo valueForKey:@"identifier"] isEqualToString:itemIdentifier] ) 
		{
            // cosmetics
			
            [toolbarItem setLabel:[[NSBundle mainBundle] localizedStringForKey:[itemInfo valueForKey:@"label"] value:@"" table:nil]];
            [toolbarItem setPaletteLabel:[[NSBundle mainBundle] localizedStringForKey:[itemInfo valueForKey:@"paletteLabel"] value:@"" table:nil]];
            [toolbarItem setToolTip:[[NSBundle mainBundle] localizedStringForKey:[itemInfo valueForKey:@"help"] value:@"" table:nil]];

            // target
			NSString *target = [[itemInfo valueForKey:@"target"] lowercaseString];
            if ( [target isEqualToString:@"windowcontroller"] ) 
			{
                [toolbarItem setTarget:self];
            }
            else if ( [target isEqualToString:@"document"] ) 
			{
                [toolbarItem setTarget:[self document]];
            }
			{
                [toolbarItem setTarget:nil];
            }
			
            // action
            if ( (nil != [itemInfo valueForKey:@"action"]) && ![[itemInfo valueForKey:@"action"] isEqualToString:@""] ) 
			{
				[toolbarItem setAction:NSSelectorFromString([itemInfo valueForKey:@"action"])];
            }
            else
			{
                [toolbarItem setAction:nil];
            }

			NSString *imageName = [itemInfo valueForKey:@"image"];
            // are we a view or an image?
            // views can still have images, so we check whether it's a view first
            if ( (nil != [itemInfo valueForKey:@"view"]) && ![[itemInfo valueForKey:@"view"] isEqualToString:@""] ) 
			{
				// we're a view, walk through the possibilities
                    // FIXME: much of this should be reduceable to an xml specification
                if ( [[itemInfo valueForKey:@"view"] isEqualToString:@"myAddPagePopUpButton"] ) 
				{
                    // construct Add Page popup
                    NSImage *image = [NSImage imageNamed:imageName];
                    [image normalizeSize];
					[image setDataRetained:YES];	// allow image to be scaled.
					image = [image imageWithCompositedAddBadge];

					[self setAddPagePopUpButton:[[[RYZImagePopUpButton alloc] initWithFrame:NSMakeRect(0, 0, [image size].width, [image size].height) pullsDown:YES] autorelease]];
                    [[myAddPagePopUpButton cell] setUsesItemFromMenu:NO];
                    [myAddPagePopUpButton setIconImage:image];
                    [myAddPagePopUpButton setShowsMenuWhenIconClicked:YES];
                    [[myAddPagePopUpButton cell] setToolbar:[[self window] toolbar]];
                    
					[KTElementPlugin addPlugins:[KTElementPlugin pagePlugins]
										 toMenu:[myAddPagePopUpButton menu]
										 target:self
										 action:@selector(addPage:)
									  pullsDown:YES
									  showIcons:YES smallIcons:NO];
                    [toolbarItem setView:myAddPagePopUpButton];
                    [toolbarItem setMinSize:[[myAddPagePopUpButton cell] minimumSize]];
                    [toolbarItem setMaxSize:[[myAddPagePopUpButton cell] maximumSize]];
					
					// Create menu for text-only view
					NSMenu *menu = [[[NSMenu alloc] init] autorelease];
					
					[KTElementPlugin addPlugins:[KTElementPlugin pagePlugins]
										 toMenu:menu
										 target:self
										 action:@selector(addPage:)
									  pullsDown:NO
									  showIcons:NO smallIcons:NO];
					NSMenuItem *mItem=[[[NSMenuItem alloc] init] autorelease];
					[mItem setSubmenu: menu];
					[mItem setTitle: [toolbarItem label]];
					[toolbarItem setMenuFormRepresentation:mItem];
					
                }
                else if ( [[itemInfo valueForKey:@"view"] isEqualToString:@"myAddPageletPopUpButton"] ) 
				{
                    // construct Add Pagelet popup
                    NSImage *image = [NSImage imageNamed:imageName];
                    [image normalizeSize];
					[image setDataRetained:YES];	// allow image to be scaled.
					// ALREADY HAS ADD BADGE INCORPORATED!  image = [image imageWithCompositedAddBadge];
                    [self setAddPageletPopUpButton:[[[RYZImagePopUpButton alloc] initWithFrame:NSMakeRect(0, 0, [image size].width, [image size].height) pullsDown:YES] autorelease]];
                    [[myAddPageletPopUpButton cell] setUsesItemFromMenu:NO];
                    [myAddPageletPopUpButton setIconImage:image];
                    [myAddPageletPopUpButton setShowsMenuWhenIconClicked:YES];
                    [[myAddPageletPopUpButton cell] setToolbar:[[self window] toolbar]];
                    
					[KTElementPlugin addPlugins:[KTElementPlugin pageletPlugins]
									     toMenu:[myAddPageletPopUpButton menu]
									     target:self
									     action:@selector(addPagelet:)
									  pullsDown:YES
									  showIcons:YES smallIcons:NO];
                    
					[toolbarItem setView:myAddPageletPopUpButton];
                    [toolbarItem setMinSize:[[myAddPageletPopUpButton cell] minimumSize]];
                    [toolbarItem setMaxSize:[[myAddPageletPopUpButton cell] maximumSize]];

					// Create menu for text-only view
					NSMenu *menu = [[[NSMenu alloc] init] autorelease];
					[KTElementPlugin addPlugins:[KTElementPlugin pageletPlugins]
									     toMenu:menu
									     target:self
									     action:@selector(addPagelet:)
									  pullsDown:NO
									  showIcons:NO smallIcons:NO];
					NSMenuItem *mItem=[[[NSMenuItem alloc] init] autorelease];
					[mItem setSubmenu: menu];
					[mItem setTitle: [toolbarItem label]];
					[toolbarItem setMenuFormRepresentation:mItem];
				}
                else if ( [[itemInfo valueForKey:@"view"] isEqualToString:@"myAddCollectionPopUpButton"] ) 
				{
                    // construct Add Page popup
                    NSImage *image = [NSImage imageNamed:imageName];
                    [image normalizeSize];
					[image setDataRetained:YES];	// allow image to be scaled.
					image = [image imageWithCompositedAddBadge];
					
                    [self setAddCollectionPopUpButton:[[[RYZImagePopUpButton alloc] initWithFrame:NSMakeRect(0, 0, [image size].width, [image size].height) pullsDown:YES] autorelease]];
                    [[myAddCollectionPopUpButton cell] setUsesItemFromMenu:NO];
                    [myAddCollectionPopUpButton setIconImage:image];
                    [myAddCollectionPopUpButton setShowsMenuWhenIconClicked:YES];
                    [[myAddCollectionPopUpButton cell] setToolbar:[[self window] toolbar]];
					
                    [KTIndexPlugin addPresetPluginsToMenu:[myAddCollectionPopUpButton menu]
                                                               target:self
                                                               action:@selector(addCollection:)
                                                            pullsDown:YES
															showIcons:YES smallIcons:NO];
                    [toolbarItem setView:myAddCollectionPopUpButton];
                    [toolbarItem setMinSize:[[myAddCollectionPopUpButton cell] minimumSize]];
                    [toolbarItem setMaxSize:[[myAddCollectionPopUpButton cell] maximumSize]];
			
					// Create menu for text-only view
					NSMenu *menu = [[[NSMenu alloc] init] autorelease];
					[KTIndexPlugin addPresetPluginsToMenu:menu
                                                               target:self
                                                               action:@selector(addCollection:)
                                                            pullsDown:NO
															showIcons:NO smallIcons:NO];
					NSMenuItem *mItem=[[[NSMenuItem alloc] init] autorelease];
					[mItem setSubmenu: menu];
					[mItem setTitle: [toolbarItem label]];
					[toolbarItem setMenuFormRepresentation:mItem];
				}
            }
            else if ( (nil != imageName) && ![imageName isEqualToString:@""] ) 
			{
				NSImage *theImage = nil;
				if ([imageName hasPrefix:@"/"])	// absolute path -- instantiate thusly
				{
					theImage = [[[NSImage alloc] initWithData:[NSData dataWithContentsOfFile:imageName]] autorelease];
				}
				else
				{
					theImage = [NSImage imageNamed:imageName];
				}
				[theImage normalizeSize];
				[theImage setDataRetained:YES];	// allow image to be scaled.
                [toolbarItem setImage:theImage];
            }
        }
    }

    return toolbarItem;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    return [[self infoForToolbar:toolbar] objectForKey:@"default set"];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar 
{
    NSMutableArray *allowedIdentifiers = [NSMutableArray array];

    NSArray *itemArray = [[self infoForToolbar:toolbar] objectForKey:@"item array"];
    NSEnumerator *enumerator = [itemArray objectEnumerator];
    NSDictionary *itemInfo;

    while ( itemInfo = [enumerator nextObject] ) 
	{
        NSString *itemIdentifier = [itemInfo valueForKey:@"identifier"];
        [allowedIdentifiers addObject:itemIdentifier];
    }
    return [NSArray arrayWithArray:allowedIdentifiers];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
    return nil; // since we're using the toolbar for actions, none are selectable
}

- (void)toolbarWillAddItem:(NSNotification *)notification
{
    ;
}

- (void)toolbarDidRemoveItem:(NSNotification *)notification
{
    ;
}

@end

