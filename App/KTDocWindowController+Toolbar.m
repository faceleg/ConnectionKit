//
//  KTDocWindowController+Toolbar.m
//  Marvel
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
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

#import "KT.h"
#import "KTElementPlugin.h"
#import "KTIndexPlugin.h"
#import "KTToolbars.h"

#import "NSImage+KTExtensions.h"
#import "NSImage+Karelia.h"
#import "NSToolbar+Karelia.h"
#import "RYZImagePopUpButton.h"
#import "RYZImagePopUpButtonCell.h"

#import "Debug.h"


@interface KTDocWindowController ( PrivateToolbar )

- (NSToolbar *)toolbarNamed:(NSString *)toolbarName;

- (void)buildAddPageletToolbarItem:(NSToolbarItem *)toolbarItem imageName:(NSString *)imageName;

@end

// NB: there's about two-thirds the work here to make this a separate controller
//  it needs a way to define views that aren't app specific, should all be doable via xml
//  for "standard" controls, like an RYZImagePopUpButton

@implementation KTDocWindowController (Toolbar)

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
}

/*  Holding down the option key should change "Publish" to "Publish All"
 *  Similar code also exists in -validateToolbarItem: since their's a few edge cases that -flagsChanged: doesn't catch
 */
- (void)flagsChanged:(NSEvent *)theEvent
{
    NSToolbarItem *toolbarItem = [[[self window] toolbar] itemWithIdentifier:@"saveToHost:"];
    [toolbarItem setLabel:([theEvent modifierFlags] & NSAlternateKeyMask ? TOOLBAR_PUBLISH_ALL : TOOLBAR_PUBLISH)];
    
    
    [super flagsChanged:theEvent];
}

#pragma mark -
#pragma mark Setup

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

- (NSToolbarItem *)makeNewPageToolbarItemWithIdentifier:(NSString *)identifier
                                              imageName:(NSString *)imageName;
{
    NSToolbarItem *result = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
    
    
    // construct popup button
    NSImage *image = [NSImage imageNamed:imageName];
    image = [image imageWithCompositedAddBadge];
    
    RYZImagePopUpButton *popUpButton = [[RYZImagePopUpButton alloc] initWithFrame:NSMakeRect(0, 0, [image size].width, [image size].height) pullsDown:YES];
    NSPopUpButtonCell *cell = [popUpButton cell];
    
    [cell setUsesItemFromMenu:NO];
    [popUpButton setIconImage:image];
    [popUpButton setShowsMenuWhenIconClicked:YES];
    [[popUpButton cell] setToolbar:[[self window] toolbar]];
    
    [result setView:popUpButton];
    [result setMinSize:[[popUpButton cell] minimumSize]];
    [result setMaxSize:[[popUpButton cell] maximumSize]];
    
    
    // Generate the menu
    NSMenu *menu = [cell menu];
    
    [cell addItemWithTitle:@"New"]; // pull-down buttons don't use the first item in their menu when displayed
    
    [menu addItemWithTitle:NSLocalizedString(@"Blank Page", "New page popup button menu item title")
                    action:@selector(addPage:)
             keyEquivalent:@""];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    [KTIndexPlugin addPresetPluginsToMenu:menu
                                   target:[self pagesController]
                                   action:@selector(addCollection:)
                                pullsDown:NO
                                showIcons:YES smallIcons:NO
                                smallText:YES allowNewPageTypes:YES];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    [menu addItemWithTitle:NSLocalizedString(@"Choose File…", "New page popup button menu item title")
                    action:@selector(addPage:)
             keyEquivalent:@""];
    
    [menu addItemWithTitle:NSLocalizedString(@"External URL", "New page popup button menu item title")
                    action:@selector(addPage:)
             keyEquivalent:@""];
    
    
    
    
    
    // Create menu for text-only version
    NSMenuItem *mItem=[[[NSMenuItem alloc] init] autorelease];
    [mItem setSubmenu:menu];
    [mItem setTitle:[result label]];
    [result setMenuFormRepresentation:mItem];
    
    
    
    return [result autorelease];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString*)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    NSToolbarItem *result = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];

    NSArray *itemsArray = [[self infoForToolbar:toolbar] objectForKey:@"item array"];
    NSEnumerator *enumerator = [itemsArray objectEnumerator];
    NSDictionary *itemInfo;

    while ( itemInfo = [enumerator nextObject] ) 
	{
        if ( [[itemInfo valueForKey:@"identifier"] isEqualToString:itemIdentifier] ) 
		{
            // Custom?
            if ([[itemInfo objectForKey:@"view"] isEqualToString:@"NewPagePopUpButton"])
            {
                result = [self makeNewPageToolbarItemWithIdentifier:itemIdentifier
                                                          imageName:[itemInfo valueForKey:@"image"]];
            }
            
            
            // cosmetics
			
            [result setLabel:[[NSBundle mainBundle] localizedStringForKey:[itemInfo valueForKey:@"label"] value:@"" table:nil]];
            [result setPaletteLabel:[[NSBundle mainBundle] localizedStringForKey:[itemInfo valueForKey:@"paletteLabel"] value:@"" table:nil]];
            [result setToolTip:[[NSBundle mainBundle] localizedStringForKey:[itemInfo valueForKey:@"help"] value:@"" table:nil]];

            // target
			NSString *target = [[itemInfo valueForKey:@"target"] lowercaseString];
            if ( [target isEqualToString:@"windowcontroller"] ) 
			{
                [result setTarget:self];
            }
            else if ( [target isEqualToString:@"document"] ) 
			{
                [result setTarget:[self document]];
            }
            else
			{
                [result setTarget:nil];
            }
			
            // action
            if ( (nil != [itemInfo valueForKey:@"action"]) && ![[itemInfo valueForKey:@"action"] isEqualToString:@""] ) 
			{
				[result setAction:NSSelectorFromString([itemInfo valueForKey:@"action"])];
            }
            else
			{
                [result setAction:nil];
            }

			NSString *imageName = [itemInfo valueForKey:@"image"];
            // are we a view or an image?
            // views can still have images, so we check whether it's a view first
            if ([[itemInfo valueForKey:@"view"] length] > 0) 
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

					RYZImagePopUpButton *addPagePopUpButton = [[RYZImagePopUpButton alloc] initWithFrame:NSMakeRect(0, 0, [image size].width, [image size].height) pullsDown:YES];
                    [[addPagePopUpButton cell] setUsesItemFromMenu:NO];
                    [addPagePopUpButton setIconImage:image];
                    [addPagePopUpButton setShowsMenuWhenIconClicked:YES];
                    [[addPagePopUpButton cell] setToolbar:[[self window] toolbar]];
                    
					[KTElementPlugin addPlugins:[KTElementPlugin pagePlugins]
										 toMenu:[addPagePopUpButton menu]
										 target:self
										 action:@selector(addPage:)
									  pullsDown:YES
									  showIcons:YES
									 smallIcons:NO 
									  smallText:YES];
                    [result setView:addPagePopUpButton];
                    [result setMinSize:[[addPagePopUpButton cell] minimumSize]];
                    [result setMaxSize:[[addPagePopUpButton cell] maximumSize]];
					
					// Create menu for text-only view
					NSMenu *menu = [[[NSMenu alloc] init] autorelease];
					
					[KTElementPlugin addPlugins:[KTElementPlugin pagePlugins]
										 toMenu:menu
										 target:self
										 action:@selector(addPage:)
									  pullsDown:NO
									  showIcons:NO
									 smallIcons:NO
									  smallText:YES];
					NSMenuItem *mItem=[[[NSMenuItem alloc] init] autorelease];
					[mItem setSubmenu: menu];
					[mItem setTitle: [result label]];
					[result setMenuFormRepresentation:mItem];
					
                }
                else if ([[itemInfo valueForKey:@"view"] isEqualToString:@"myAddPageletPopUpButton"]) 
				{
					[self buildAddPageletToolbarItem:result imageName:imageName];
				}
                else if ( [[itemInfo valueForKey:@"view"] isEqualToString:@"myAddCollectionPopUpButton"] ) 
				{
                    // construct Add Page popup
                    NSImage *image = [NSImage imageNamed:imageName];
                    [image normalizeSize];
					[image setDataRetained:YES];	// allow image to be scaled.
					image = [image imageWithCompositedAddBadge];
					
                    RYZImagePopUpButton *addCollectionPopUpButton = [[RYZImagePopUpButton alloc] initWithFrame:NSMakeRect(0, 0, [image size].width, [image size].height) pullsDown:YES];
                    [[addCollectionPopUpButton cell] setUsesItemFromMenu:NO];
                    [addCollectionPopUpButton setIconImage:image];
                    [addCollectionPopUpButton setShowsMenuWhenIconClicked:YES];
                    [[addCollectionPopUpButton cell] setToolbar:[[self window] toolbar]];
					
                    [KTIndexPlugin addPresetPluginsToMenu:[addCollectionPopUpButton menu]
												   target:self
												   action:@selector(addCollection:)
												pullsDown:YES
												showIcons:YES smallIcons:NO
												smallText:YES allowNewPageTypes:YES];
                    [result setView:addCollectionPopUpButton];
                    [result setMinSize:[[addCollectionPopUpButton cell] minimumSize]];
                    [result setMaxSize:[[addCollectionPopUpButton cell] maximumSize]];
			
					// Create menu for text-only view
					NSMenu *menu = [[[NSMenu alloc] init] autorelease];
					[KTIndexPlugin addPresetPluginsToMenu:menu
												   target:self
												   action:@selector(addCollection:)
												pullsDown:NO
												showIcons:NO smallIcons:NO
												smallText:YES allowNewPageTypes:YES];
					NSMenuItem *mItem=[[[NSMenuItem alloc] init] autorelease];
					[mItem setSubmenu: menu];
					[mItem setTitle: [result label]];
					[result setMenuFormRepresentation:mItem];
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
                [result setImage:theImage];
            }
        }
    }

    return result;
}

/*	Support method that turns toolbarItem into a "Add Pagelet" button
 */
- (void)buildAddPageletToolbarItem:(NSToolbarItem *)toolbarItem imageName:(NSString *)imageName
{
	// Preapre the image	// ALREADY HAS ADD BADGE INCORPORATED!  image = [image imageWithCompositedAddBadge];
	NSImage *image = [NSImage imageNamed:imageName];
	[image normalizeSize];
	[image setDataRetained:YES];	// allow image to be scaled.
	
	
	// Build the basic popup button
	RYZImagePopUpButton *button = [[[RYZImagePopUpButton alloc] initWithFrame:NSMakeRect(0, 0, [image size].width, [image size].height) pullsDown:YES] autorelease];
	[[button cell] setUsesItemFromMenu:NO];
	[button setIconImage:image];
	[button setShowsMenuWhenIconClicked:YES];
	[[button cell] setToolbar:[[self window] toolbar]];
	
	
	// Disable the button for pages that don't support it.
	OBASSERTSTRING([self siteOutlineViewController], @"Could not bind Pagelets popup button as there is no Site Outline controller");
	NSDictionary *options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO]
														forKey:NSMultipleValuesPlaceholderBindingOption];
	
	
	// Add the proper menu items
	[KTElementPlugin addPlugins:[KTElementPlugin pageletPlugins]
						 toMenu:[button menu]
						 target:self
						 action:@selector(insertElement:)
					  pullsDown:YES
					  showIcons:YES smallIcons:NO smallText:YES];
	
	
	// Control sizing
	[toolbarItem setView:button];
	[toolbarItem setMinSize:[[button cell] minimumSize]];
	[toolbarItem setMaxSize:[[button cell] maximumSize]];


	// Create menu for text-only view
	NSMenu *menu = [[[NSMenu alloc] init] autorelease];
	[KTElementPlugin addPlugins:[KTElementPlugin pageletPlugins]
						 toMenu:menu
						 target:self
						 action:@selector(insertElement:)
					  pullsDown:NO
					  showIcons:NO smallIcons:NO
					  smallText:YES];
	NSMenuItem *mItem=[[[NSMenuItem alloc] init] autorelease];
	[mItem setSubmenu: menu];
	[mItem setTitle: [toolbarItem label]];
	[toolbarItem setMenuFormRepresentation:mItem];
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

