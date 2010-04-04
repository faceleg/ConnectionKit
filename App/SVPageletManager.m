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
    // First go through and get the localized names of each bundle, and put into a dict keyed by name
	NSMutableDictionary *dictOfPlugins = [NSMutableDictionary dictionary];
	
    // go through each plugin.
    KTHTMLPlugInWrapper *plugin;
	NSSet *plugins = [KTElementPlugInWrapper pageletPlugins];
	for (plugin in plugins)
	{
		int priority = 5;		// default if unspecified (RichText=1, Photo=2, other=5, Advanced HTML = 9
		id priorityID = [plugin pluginPropertyForKey:@"KTPluginPriority"];
		if (nil != priorityID)
		{
			priority = [priorityID intValue];
		}
		if (priority > 0	// don't add zero-priority items to menu!
			&& (priority < 9 || (nil == gRegistrationString) || gIsPro) )	// only if non-advanced or advanced allowed.
		{
			NSString *pluginName = [plugin pluginPropertyForKey:@"KTPluginName"];
			
			[dictOfPlugins setObject:plugin
							  forKey:[NSString stringWithFormat:@"%d %@", priority, pluginName]];
		}
	}
	
	// Now add the sorted arrays
	NSArray *sortedPriorityNames = [[dictOfPlugins allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	NSEnumerator *sortedEnum = [sortedPriorityNames objectEnumerator];
	NSString *priorityAndName;
	
	while (nil != (priorityAndName = [sortedEnum nextObject]) )
	{
		KTHTMLPlugInWrapper *plugin = [dictOfPlugins objectForKey:priorityAndName];
		NSBundle *bundle = [plugin bundle];
		
        if (![bundle isLoaded] && [bundle principalClassIncludingOtherLoadedBundles:YES]) [bundle load];
        
		NSMenuItem *menuItem = [[[NSMenuItem alloc] init] autorelease];
		
		NSString *pluginName = [plugin pluginPropertyForKey:@"KTPluginName"];
		
		
		id priorityID = [plugin pluginPropertyForKey:@"KTPluginPriority"];
		NSInteger priority = 5;
		if (priorityID) priority = [priorityID integerValue];
		
		
		if (!pluginName || [pluginName isEqualToString:@""])
		{
			NSLog(@"empty plugin name for %@", plugin);
			pluginName = @"";
		}
		
		// set up the image
		{
			NSImage *image = [[plugin pluginIcon] copy];
#ifdef DEBUG
			if (!image) NSLog(@"nil pluginIcon for %@", pluginName);
#endif
			
            [image setSize:NSMakeSize(32.0f, 32.0f)];
			// FIXME: it would be better to pre-scale images in the same family rather than scale here, larger than 32 might be warranted in some cases, too
			[menuItem setImage:image];
            [image release];
			
			
            [menuItem setTitle:pluginName];
			if (9 == priority && nil == gRegistrationString)
			{
				[[NSApp delegate] setMenuItemPro:menuItem];
			}
		}
		
		
		if ([plugin isKindOfClass:[KTElementPlugInWrapper class]])
		{
			[menuItem setRepresentedObject:plugin];
		}
		else
		{
			[menuItem setRepresentedObject:[[plugin bundle] bundleIdentifier]];
		}
		
		// set target/action
		[menuItem setAction:@selector(insertPagelet:)];
		
		[menu insertItem:menuItem atIndex:index];   index++;
	}
}

@end
