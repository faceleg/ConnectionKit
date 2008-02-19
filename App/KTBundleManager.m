//
//  KTBundleManager.m
//  Marvel
//
//  Copyright (c) 2004-2005 Biophony, LLC. All rights reserved.
//

/*
PURPOSE OF THIS CLASS/CATEGORY:
	General manager of all our bundl/plugin objects

TAXONOMY AND RELATIONSHIP TO OTHER CLASSES:
	One bundle manager is owned by Application Delegate.

IMPLEMENTATION NOTES & CAUTIONS:
	
	Note: a lot of bundle manager functionality is also found in KTUtilities.m

TO DO:
	x

 */

#import "KTBundleManager.h"

#import "KT.h"
#import "KTElementPlugin.h"
#import "KTAppDelegate.h"
#import "KTComponents.h"
#import "PrivateComponents.h"
#import "Registration.h"

@interface KTAppDelegate ( PrivateHack )
- (void)setMenuItemPro:(NSMenuItem *)aMenuItem;
@end

@interface KTBundleManager (Private)
- (NSDictionary *)availablePlugins;
@end


#pragma mark -


@implementation KTBundleManager

#pragma mark -
#pragma mark Dealloc

- (void)dealloc
{
    [myPluginsByIdentifier release];
	[myDataSourceObjects release];

    [super dealloc];
}

#pragma mark -
#pragma mark Plugins List

- (NSDictionary *)registeredPlugins
{
	// Upon first access, load the plugins
	if (!myPluginsByIdentifier)
	{
		NSMutableDictionary *buffer = [NSMutableDictionary dictionary];
		
		NSSet *extensionsToCheck = [NSSet setWithObjects:kKTPageletExtension, kKTPageExtension,
			kKTIndexExtension, kKTElementExtension, kKTDataSourceExtension, nil];
		NSEnumerator *extensionsEnumerator = [extensionsToCheck objectEnumerator];
		NSString *extension;

		while (extension = [extensionsEnumerator nextObject])
		{
			NSDictionary *plugins = [KTUtilities pluginsWithExtension:extension sisterDirectory:@"Plugins"];
			if (plugins)
			{
				[buffer addEntriesFromDictionary:plugins];
			}
		}
		
		myPluginsByIdentifier = [[NSDictionary alloc] initWithDictionary:buffer];
	}
	
	
	return myPluginsByIdentifier;
}

/*! Returns the best plugin with that identifier
 */
- (KTAppPlugin *)pluginWithIdentifier:(NSString *)anIdentifier
{
    [self registeredPlugins];	// Ensure plugins are loaded
    return [KTAppPlugin pluginWithIdentifier:anIdentifier];
}

/*	Returns those registeredPlugins of the specified type
 */
- (NSDictionary *)pluginsOfType:(NSString *)aPluginType
{
	NSDictionary *registeredPlugins = [self registeredPlugins];
	NSMutableDictionary *buffer = [NSMutableDictionary dictionaryWithCapacity:[registeredPlugins count]];
	
	NSEnumerator *pluginsEnumerator = [registeredPlugins objectEnumerator];
	KTAppPlugin *aPlugin;
	while (aPlugin = [pluginsEnumerator nextObject])
	{
		if ([[aPlugin pluginType] isEqualToString:aPluginType] && [[aPlugin bundle] bundleIdentifier])
		{
			[buffer setObject:aPlugin forKey:[[aPlugin bundle] bundleIdentifier]];
		}
	}
	
	NSDictionary *result = [NSDictionary dictionaryWithDictionary:buffer];
	return result;
}

/*	Returns all registered plugins that are either:
 *		A) Of the svxPage plugin type
 *		B) Of the svxElement plugin type and support page usage
 */
- (NSSet *)pagePlugins
{
	NSDictionary *registeredPlugins = [self registeredPlugins];
	NSMutableSet *buffer = [NSMutableSet setWithCapacity:[registeredPlugins count]];
	
	NSEnumerator *pluginsEnumerator = [registeredPlugins objectEnumerator];
	KTAppPlugin *aPlugin;
	while (aPlugin = [pluginsEnumerator nextObject])
	{
		NSString *pluginType = [aPlugin pluginType];
		if ([pluginType isEqualToString:kKTPageExtension] ||
				([pluginType isEqualToString:kKTElementExtension] &&
				[[aPlugin pluginPropertyForKey:@"KTElementSupportsPageUsage"] boolValue])
		   )
		{
			[buffer addObject:aPlugin];
		}
	}
	
	NSSet *result = [NSSet setWithSet:buffer];
	return result;
}

/*	Returns all registered plugins that are either:
 *		A) Of the svxPagelet plugin type
 *		B) Of the svxElement plugin type and support pagelet usage
 */
- (NSSet *)pageletPlugins
{
	NSDictionary *registeredPlugins = [self registeredPlugins];
	NSMutableSet *buffer = [NSMutableSet setWithCapacity:[registeredPlugins count]];
	
	NSEnumerator *pluginsEnumerator = [registeredPlugins objectEnumerator];
	KTAppPlugin *aPlugin;
	while (aPlugin = [pluginsEnumerator nextObject])
	{
		NSString *pluginType = [aPlugin pluginType];
		if ([pluginType isEqualToString:kKTPageletExtension] ||
				([pluginType isEqualToString:kKTElementExtension] &&
				[[aPlugin pluginPropertyForKey:@"KTElementSupportsPageletUsage"] boolValue])
		   )
		{
			[buffer addObject:aPlugin];
		}
	}
	
	NSSet *result = [NSSet setWithSet:buffer];
	return result;
}

- (NSArray *)dataSourceObjects
{
	if (nil == myDataSourceObjects)	// lazily instantiate
	{
		myDataSourceObjects = [[self loadAllPluginClassesOfType:kKTDataSourceExtension instantiate:YES] retain];
	}
	return myDataSourceObjects;
}

- (NSArray *)managedObjectModels
{
	NSMutableArray *array = [NSMutableArray array];

	NSEnumerator *e = [[self availablePlugins] objectEnumerator];
	NSBundle *plugin;
	while ( plugin = [e nextObject] )
	{
		NSArray *momPaths = [plugin pathsForResourcesOfType:@"mom" inDirectory:nil];

//		NSLog(@"plugin path = %@", [plugin resourcePath]);
//		NSLog(@"momPaths = %@", momPaths);

		NSEnumerator *pathEnumerator = [momPaths objectEnumerator];
		NSString *path;
		while ( path = [pathEnumerator nextObject] )
		{
			NSManagedObjectModel *mom = [NSManagedObjectModel modelWithPath:path];
			if ( nil != mom )
			{
				[array addObject:mom];
			}
		}
	}

//	NSLog(@"MOMs = %@", [array description]);
	return [NSArray arrayWithArray:array];
}

- (NSString *)pluginReportShowingAll:(BOOL)aShowAll	// if false, just shows third-party ones
{
	NSMutableString *string = [NSMutableString string];
	NSString *builtInPath = [[NSBundle mainBundle] builtInPlugInsPath];
	NSDictionary *allPlugins = [self registeredPlugins];
	NSEnumerator *theEnum = [allPlugins objectEnumerator];
	NSBundle *bundle;

	while (nil != (bundle = [theEnum nextObject]) )
	{
		NSString *bundlePath = [bundle bundlePath];
		if ([bundlePath hasPrefix:builtInPath] && !aShowAll)
		{
			continue;
		}
		NSString *identifier = [bundle bundleIdentifier];
		if (nil == identifier)
		{
			identifier = bundlePath;		// in case identifier is not there
		}
		[string appendFormat:@"%@\t%@", identifier, [bundle version]];
		if (nil != [bundle buildVersion])
		{
			[string appendFormat:@" (%@)", [bundle buildVersion]];
		}
		[string appendString:@"\n"];
	}
	return string;
}

#pragma mark -
#pragma mark Plugin Handling

// nil targeted actions will be sent to firstResponder (the active document)
// representedObject is the bundle of the plugin
- (void)addPlugins:(NSSet *)plugins
		    toMenu:(NSMenu *)aMenu
		    target:(id)aTarget
		    action:(SEL)anAction
	     pullsDown:(BOOL)isPullDown
	     showIcons:(BOOL)showIcons
{
    if ( isPullDown ) {
        // if it's a pulldown, we need to add an empty menu item at the top of the menu
        [aMenu addItem:[[[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""] autorelease]];
    }

	// First go through and get the localized names of each bundle, and put into a dict keyed by name
	NSMutableDictionary *dictOfBundles = [NSMutableDictionary dictionary];
	
   NSEnumerator *enumerator = [plugins objectEnumerator];	// go through each plugin.
    KTAbstractHTMLPlugin *plugin;
 
	while (plugin = [enumerator nextObject])
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
			if (anAction == @selector(addPage:)) {
				pluginName = [plugin pluginPropertyForKey:@"KTPageName"];
			}
			else if (anAction == @selector(addPagelet:)) {
				pluginName = [plugin pluginPropertyForKey:@"KTPageletName"];
			}
			
			[dictOfBundles setObject:[plugin bundle]
							  forKey:[NSString stringWithFormat:@"%d %@", priority, pluginName]];
		}
	}

	// Now add the sorted arrays
	NSArray *sortedPriorityNames = [[dictOfBundles allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	NSEnumerator *sortedEnum = [sortedPriorityNames objectEnumerator];
	NSString *priorityAndName;

	while (nil != (priorityAndName = [sortedEnum nextObject]) )
	{
		NSBundle *bundle = [dictOfBundles objectForKey:priorityAndName];
		KTAbstractHTMLPlugin *plugin = [KTAppPlugin pluginWithBundle:bundle];
		
        if ( ![bundle isLoaded] && (Nil != [NSBundle principalClassForBundle:bundle]) ) {
            [bundle load];
        }
		NSMenuItem *menuItem = [[[NSMenuItem alloc] init] autorelease];
		NSMutableParagraphStyle *style = [[[NSMutableParagraphStyle alloc] init] autorelease];
		
		NSString *pluginName = [plugin pluginPropertyForKey:@"KTPluginName"];
		if (anAction == @selector(addPage:)) {
			pluginName = [plugin pluginPropertyForKey:@"KTPageName"];
		}
		else if (anAction == @selector(addPagelet:)) {
			pluginName = [plugin pluginPropertyForKey:@"KTPageName"];
		}
		
			
		id priorityID = [plugin pluginPropertyForKey:@"KTPluginPriority"];
		int priority = 5;
		if (nil != priorityID)
		{
			priority = [priorityID intValue];
		}
		
		
		if (!pluginName || [pluginName isEqualToString:@""])
		{
			NSLog(@"empty plugin name for %@", plugin);
			pluginName = @"";
		}
		
		// set up the image
		if (showIcons)
		{
			NSImage *image = [plugin pluginIcon];
#ifdef DEBUG
			if (nil == image)
			{
				NSLog(@"nil pluginIcon for %@", pluginName);
			}
#endif
				
			[image setDataRetained:YES];	// allow image to be scaled.
			[image setScalesWhenResized:YES];
	// FIXME: it would be better to pre-scale images in the same family rather than scale here, larger than 32 might be warranted in some cases, too
			[image setSize:NSMakeSize(32.0, 32.0)];
			[menuItem setImage:image];
			[style setMinimumLineHeight:[image size].height];

			NSFont *titleFont = [NSFont menuFontOfSize:[NSFont smallSystemFontSize]];
			NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
				titleFont, NSFontAttributeName,
				style, NSParagraphStyleAttributeName,
				[NSNumber numberWithFloat:((([image size].height-[NSFont smallSystemFontSize])/2.0)+2.0)], NSBaselineOffsetAttributeName,
				nil];
			NSAttributedString *titleString = [[[NSAttributedString alloc] initWithString:pluginName attributes:attributes] autorelease];
			[menuItem setAttributedTitle:titleString];
			if (9 == priority && nil == gRegistrationString)
			{
				[(KTAppDelegate *)[NSApp delegate] setMenuItemPro:menuItem];
			}
		}
		else
		{
			[menuItem setTitle:pluginName];
		}
		
		// set target/action
		[menuItem setRepresentedObject:plugin];
		[menuItem setAction:anAction];
		[menuItem setTarget:aTarget];
		
		[aMenu addItem:menuItem];
	}
}


// Special version of above, but it looks for KTPresets and adds those items to the menu

- (void)addPresetPluginsOfType:(NSString *)aPluginType
						toMenu:(NSMenu *)aMenu
						target:(id)aTarget
						action:(SEL)anAction
					 pullsDown:(BOOL)isPullDown
					 showIcons:(BOOL)showIcons
{
    if ( isPullDown ) {
        // if it's a pulldown, we need to add an empty menu item at the top of the menu
        [aMenu addItem:[[[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""] autorelease]];
    }
	
	// First go through and get the localized names of each bundle, and put into a dict keyed by name
	NSMutableDictionary *dictOfPresets = [NSMutableDictionary dictionary];

    NSDictionary *plugins = [self pluginsOfType:aPluginType];
    NSEnumerator *enumerator = [plugins objectEnumerator];	// go through each plugin.
    KTAbstractHTMLPlugin *plugin;
    
	while (plugin = [enumerator nextObject])
	{
		NSBundle *bundle = [plugin bundle];
		
		NSArray *presets = [bundle objectForInfoDictionaryKey:@"KTPresets"];
		NSEnumerator *presetEnum = [presets objectEnumerator];
		NSDictionary *presetDict;

		while (nil != (presetDict = [presetEnum nextObject]) )
		{
			int priority = 5;		// default if unspecified (RichText=1, Photo=2, other=5, Advanced HTML = 9
			id priorityID = [presetDict objectForKey:@"KTPluginPriority"];
			if (nil != priorityID)
			{
				priority = [priorityID intValue];
			} 
			if (priority > 0	// don't add zero-priority items to menu!
				&& (priority < 9 || (nil == gRegistrationString) || gIsPro) )	// only if non-advanced or advanced allowed.
			{
				NSString *englishPresetTitle = [presetDict objectForKey:@"KTPresetTitle"];
				NSString *presetTitle = [bundle localizedStringForKey:englishPresetTitle value:englishPresetTitle table:nil];
				
				NSMutableDictionary *newPreset = [NSMutableDictionary dictionaryWithDictionary:presetDict];
				[newPreset setObject:[bundle bundleIdentifier] forKey:@"KTPresetIndexBundleIdentifier"];
				
				[dictOfPresets setObject:[NSDictionary dictionaryWithDictionary:newPreset]
								  forKey:[NSString stringWithFormat:@"%d %@", priority, presetTitle]];
			}
		}
	}
	
	// Now add the sorted arrays
	NSArray *sortedPriorityNames = [[dictOfPresets allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	NSEnumerator *sortedEnum = [sortedPriorityNames objectEnumerator];
	NSString *priorityAndName;
	
	while (nil != (priorityAndName = [sortedEnum nextObject]) )
	{
		NSDictionary *presetDict = [dictOfPresets objectForKey:priorityAndName];
		NSString *bundleIdentifier = [presetDict objectForKey:@"KTPresetIndexBundleIdentifier"];
		
		KTAppPlugin *plugin = [self pluginWithIdentifier:bundleIdentifier];
		NSBundle *pluginBundle = [plugin bundle];
		
        if ( ![pluginBundle isLoaded] && (Nil != [NSBundle principalClassForBundle:pluginBundle]) ) {
            [pluginBundle load];
        }
		NSMenuItem *menuItem = [[[NSMenuItem alloc] init] autorelease];
		NSMutableParagraphStyle *style = [[[NSMutableParagraphStyle alloc] init] autorelease];

		NSString *englishPresetTitle = [presetDict objectForKey:@"KTPresetTitle"];
		NSString *presetTitle = [pluginBundle localizedStringForKey:englishPresetTitle value:englishPresetTitle table:nil];
		id priorityID = [presetDict objectForKey:@"KTPluginPriority"];
		int priority = 5;
		if (nil != priorityID)
		{
			priority = [priorityID intValue];
		} 
		
		
		// set up the image
		if (showIcons)
		{
			NSImage *image = [[KTAppPlugin pluginWithBundle:pluginBundle] pluginIcon];
#ifdef DEBUG
			if (nil == image)
			{
				NSLog(@"nil pluginIcon for %@", presetTitle);
			}
#endif
			
			[image setDataRetained:YES];	// allow image to be scaled.
			[image setScalesWhenResized:YES];
// FIXME: it would be better to pre-scale images in the same family rather than scale here, larger than 32 might be warranted in some cases, too
			[image setSize:NSMakeSize(32.0, 32.0)];
			[menuItem setImage:image];
			[style setMinimumLineHeight:[image size].height];
			
			NSFont *titleFont = [NSFont menuFontOfSize:[NSFont smallSystemFontSize]];
			NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
				titleFont, NSFontAttributeName,
				style, NSParagraphStyleAttributeName,
				[NSNumber numberWithFloat:((([image size].height-[NSFont smallSystemFontSize])/2.0)+2.0)], NSBaselineOffsetAttributeName,
				nil];
			NSAttributedString *titleString = [[[NSAttributedString alloc] initWithString:presetTitle attributes:attributes] autorelease];
			[menuItem setAttributedTitle:titleString];
		}
		else
		{
			[menuItem setTitle:presetTitle];
		}
		
		if (9 == priority && nil == gRegistrationString)
		{
			[(KTAppDelegate *)[NSApp delegate] setMenuItemPro:menuItem];
		}
		
		// set target/action
		[menuItem setRepresentedObject:presetDict];
		[menuItem setAction:anAction];
		[menuItem setTarget:aTarget];
		
		[aMenu addItem:menuItem];
	}
}


- (BOOL)loadClassNamed:(NSString *)aClassName pluginType:(NSString *)aPluginType
{
    NSDictionary *plugins = [self pluginsOfType:aPluginType];
    NSEnumerator *enumerator = [plugins objectEnumerator];
    NSBundle *plugin;

    while ( plugin = [enumerator nextObject] ) {
        NSString *principalClassName = NSStringFromClass([plugin principalClass]);
        if (  [principalClassName isEqualToString:aClassName] ) {
            return (Nil != [plugin classNamed:aClassName]);
        }
    }

    // nothing found
    return NO;
}

// Load the plug-in classes.  If inInstantiate is YES, then return an arrayy of instantiated classes.

- (NSArray *)loadAllPluginClassesOfType:(NSString *)aPluginType instantiate:(BOOL)inInstantiate
{
    NSDictionary *plugins = [self pluginsOfType:aPluginType];

	NSMutableArray *result = nil;
	if (inInstantiate)
	{
		result = [NSMutableArray array];
	}

    NSEnumerator *enumerator = [plugins objectEnumerator];	// loop through each pluging
    KTAppPlugin *plugin;
	while (plugin = [enumerator nextObject])
	{
		NSBundle *pluginBundle = [plugin bundle];
		
		[pluginBundle load];
		Class theClass = [pluginBundle principalClass];
        if ( nil != theClass ) {

			// Make class get loaded
            if ( inInstantiate )
			{
				id theObject = [[[theClass alloc] init] autorelease];
				if (nil == theObject)
				{
					NSLog(@"Unable to instantiate object of class %@ from bundle %@", 
						  NSStringFromClass([NSBundle principalClassForBundle:pluginBundle]), plugin);
				}
				else
				{
					[result addObject:theObject];
				}
            }
        }
    }
	return result;
}

/*! returns array of setOfAllDragSourceAcceptedDragTypesForPagelets:(BOOL)isPagelet */
- (NSArray *)allDragSourceAcceptedDragTypesForPagelets:(BOOL)isPagelet
{
    return [NSArray arrayWithArray:[[self setOfAllDragSourceAcceptedDragTypesForPagelets:isPagelet] allObjects]];
}

/*! returns unionSet of acceptedDragTypes from all known KTDataSources */
- (NSSet *)setOfAllDragSourceAcceptedDragTypesForPagelets:(BOOL)isPagelet
{
    NSMutableSet *typesSet = [NSMutableSet setWithCapacity:10];

    NSEnumerator *e = [[self dataSourceObjects] objectEnumerator];
    id dataSource;

    while (dataSource = [e nextObject] )
    {
		NSArray *acceptedTypes = [dataSource acceptedDragTypesCreatingPagelet:isPagelet];
		if (nil != acceptedTypes)
		{
			[typesSet addObjectsFromArray:acceptedTypes];
		}
    }

    return [NSSet setWithSet:typesSet];
}

@end
