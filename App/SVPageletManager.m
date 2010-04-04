//
//  SVPageletManager.m
//  Sandvox
//
//  Created by Mike on 04/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVPageletManager.h"

#import "KTElementPlugInWrapper.h"
#import "SVGraphicRegistrationInfo.h"

#import "NSSet+Karelia.h"

#import "Registration.h"


@implementation SVPageletManager

static SVPageletManager *sSharedPageletManager;

+ (void)initialize
{
    if (!sSharedPageletManager) sSharedPageletManager = [[SVPageletManager alloc] init];
}

+ (SVPageletManager *)sharedPageletManager; { return sSharedPageletManager; }

- (id)init
{
    [super init];
    
    _pageletClasses = [[NSMutableArray alloc] init];
    
    return self;
}

#pragma mark Registration

- (void)registerPageletClass:(Class)pageletClass
                        icon:(NSImage *)icon;
{
    OBPRECONDITION(pageletClass);
    OBPRECONDITION(icon);
    
    SVGraphicRegistrationInfo *info = [[SVGraphicRegistrationInfo alloc]
                                       initWithPageletClass:pageletClass
                                       icon:icon];
    [_pageletClasses addObject:info];
    [info release];
}

#pragma mark Menu

// nil targeted actions will be sent to firstResponder (the active document)
// representedObject is the bundle of the plugin
- (void)populateMenu:(NSMenu *)menu atIndex:(NSUInteger)index;
{	
    // Order plug-ins first by priority, then by name
    NSSet *plugins = [KTElementPlugInWrapper pageletPlugins];
    
    NSSortDescriptor *prioritySort = [[NSSortDescriptor alloc] initWithKey:@"priority"
                                                                 ascending:YES];
    NSSortDescriptor *nameSort = [[NSSortDescriptor alloc]
                                  initWithKey:@"name"
                                  ascending:YES
                                  selector:@selector(caseInsensitiveCompare:)];
    
    NSArray *sortDescriptors = [NSArray arrayWithObjects:prioritySort, nameSort, nil];
    [prioritySort release];
    [nameSort release];
    
    NSArray *sortedPlugins = [plugins KS_sortedArrayUsingDescriptors:sortDescriptors];
    
    
    
	
    
    
	// Now add the sorted arrays
	KTHTMLPlugInWrapper *plugin;
	for (plugin in sortedPlugins)
	{
		NSMenuItem *menuItem = [[[NSMenuItem alloc] init] autorelease];
		
		NSString *pluginName = [plugin pluginPropertyForKey:@"KTPluginName"];
		
		
		if (!pluginName || [pluginName isEqualToString:@""])
		{
			NSLog(@"empty plugin name for %@", plugin);
			pluginName = @"";
		}
		
        
		// Icon
        NSImage *image = [[plugin pluginIcon] copy];
#ifdef DEBUG
        if (!image) NSLog(@"nil pluginIcon for %@", pluginName);
#endif
        
        [image setSize:NSMakeSize(32.0f, 32.0f)];
        // FIXME: it would be better to pre-scale images in the same family rather than scale here, larger than 32 might be warranted in some cases, too
        [menuItem setImage:image];
        [image release];
        
        
        [menuItem setTitle:pluginName];
        if (9 == [plugin priority] && nil == gRegistrationString)
        {
            [[NSApp delegate] setMenuItemPro:menuItem];
        }
		
        
		
		[menuItem setRepresentedObject:plugin];
        
		
		// set target/action
		[menuItem setAction:@selector(insertPagelet:)];
		
		[menu insertItem:menuItem atIndex:index];   index++;
	}
}

@end
