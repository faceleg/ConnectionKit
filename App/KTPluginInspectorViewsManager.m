//
//  KTPluginInspectorViewsManager.m
//  Marvel
//
//  Created by Mike on 28/08/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTPluginInspectorViewsManager.h"


@interface NSNib (KTPlugins)

+ (NSNib *)nibForPlugin:(id <KTInspectorPlugin>)plugin;

- (BOOL)instantiatePluginNibWithOwner:(id)owner plugin:(id <KTInspectorPlugin>)plugin
					  topLevelObjects:(NSArray **)topLevelObjects
						inspectorView:(NSView **)inspectorView
					 objectController:(NSObjectController **)objectController;

@end


@interface KTPluginInspectorViewsManager (Private)
+ (NSMutableDictionary *)pluginNibsDictionary;

- (void)loadNibFileForPlugin:(id <KTInspectorPlugin>)plugin;
@end


#pragma mark -


@implementation KTPluginInspectorViewsManager

#pragma mark -
#pragma mark Alloc & Dealloc

- (id)init
{
	[super init];
	
	myPluginTopLevelObjects = [[NSMutableDictionary alloc] init];
	myPluginInspectorViews = [[NSMutableDictionary alloc] init];
	myPluginControllers = [[NSMutableDictionary alloc] init];
	
	return self;
}

- (void)dealloc
{
	// Disconnect each plugin's controller from its content to ensure nothing tries to access the MOC later.
	[[myPluginControllers allValues] makeObjectsPerformSelector:@selector(setContent:) withObject:nil];
	
	[myPluginControllers release];
	[myPluginInspectorViews release];
	[myPluginTopLevelObjects release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Inspector view

/*	Returns the Inspector view for the given plugin, loading it from the nib file if needed
 */
- (NSView *)inspectorViewForPlugin:(id <KTInspectorPlugin>)plugin
{
	NSView *result = [myPluginInspectorViews objectForKey:[plugin uniqueID]];
	
	// If no Inspector view is found, try to load the plugin's nib file and return the result of that.
	if (!result)
	{
		[self loadNibFileForPlugin:plugin];
		result = [myPluginInspectorViews objectForKey:[plugin uniqueID]];
	}
	
	return result;
}

- (void)loadNibFileForPlugin:(id <KTInspectorPlugin>)plugin
{
	NSNib *nib = [NSNib nibForPlugin:plugin];
	
	// If the plugin has no nib file then just bail
	if (!nib) {
		return;
	}
	
	// Load the nib
	NSArray *topLevelObjects = nil;
	NSView *inspectorView = nil;
	NSObjectController *objectController = nil;
	BOOL succeeded = [nib instantiatePluginNibWithOwner:[plugin inspectorNibOwner]
												 plugin:[plugin inspectorObject]
										topLevelObjects:&topLevelObjects
										  inspectorView:&inspectorView
									   objectController:&objectController];
	
	// Bail if we couldn't load the nib
	if (!succeeded || !inspectorView)
	{
		[self raiseExceptionWithName:kKTGenericPluginException 
							  reason:@"Unable to load inspector from bundle, file is missing or not configured right." 
							userInfo:[NSDictionary dictionaryWithObject:[[plugin inspectorNibBundle] bundleIdentifier] forKey:@"plugin"]];
							
		return;
	}
	
	// Store the various nib objects
	[myPluginInspectorViews setValue:inspectorView forKey:[plugin uniqueID]];
	[myPluginControllers setValue:objectController forKey:[plugin uniqueID]];
	[myPluginTopLevelObjects setObject:topLevelObjects forKey:[plugin uniqueID]];
	[topLevelObjects makeObjectsPerformSelector:@selector(release)];	// Cancels out the retain from loading the nib
}

/*	Handy if you need to trim memory usage. e.g. you know the plugin will never have its view displayed again.
 */
- (void)removeInspectorViewForPlugin:(id <KTInspectorPlugin>)plugin
{
	[myPluginControllers removeObjectForKey:[plugin uniqueID]];
	[myPluginTopLevelObjects removeObjectForKey:[plugin uniqueID]];
	[myPluginInspectorViews removeObjectForKey:[plugin uniqueID]];
}

@end


#pragma mark -


@implementation NSNib (KTPlugins)

/*	Simple class accessor for use internally by +nibForPlugin:
 */
+ (NSMutableDictionary *)pluginNibsDictionary
{
	static NSMutableDictionary *pluginNibs;
	if (!pluginNibs)
	{
		pluginNibs = [[NSMutableDictionary alloc] init];
	}
	return pluginNibs;
}

/*	We load the nib for each plugin type into memory just once
 */
+ (NSNib *)nibForPlugin:(id <KTInspectorPlugin>)plugin
{
	NSBundle *nibBundle = [plugin inspectorNibBundle];
	NSString *nibName = [plugin inspectorNibName];
	
	NSString *nibIdentifier = [NSString stringWithFormat:@"%@/%@", [nibBundle bundleIdentifier], nibName];
	
	NSNib *result = [[self pluginNibsDictionary] objectForKey:nibIdentifier];
	
	if (!result)
	{
		if (nibBundle && nibName)
		{
			result = [[NSNib alloc] initWithNibNamed:nibName bundle:nibBundle];
			[[self pluginNibsDictionary] setObject:result forKey:nibIdentifier];
			[result release];
		}
	}
	
	return result;
}

/*	Instantiates the nib as per normal but then also figures out which objects are the inspector view and object controller.
 *	Also then hooks up the object controller to the plugin.
 */
- (BOOL)instantiatePluginNibWithOwner:(id)owner plugin:(id <KTInspectorPlugin>)plugin
					  topLevelObjects:(NSArray **)topLevelObjects
						inspectorView:(NSView **)inspectorView
					 objectController:(NSObjectController **)objectController
{
	BOOL result = [self instantiateNibWithOwner:owner topLevelObjects:topLevelObjects];
	
	if (result)
	{
		// Search for the inspector view and object controller
		*inspectorView = nil;
		*objectController = nil;
		NSEnumerator *enumerator = [*topLevelObjects objectEnumerator];
		id anObject;
		
		while (anObject = [enumerator nextObject])
		{
			if ([anObject isKindOfClass:[NSObjectController class]] && ![anObject content])
			{
				if (*objectController)	// Already thinks it has an object controller? Could be a problem!
				{
					NSString *identifier = [[plugin inspectorNibBundle] bundleIdentifier];
					[self raiseExceptionWithName:kKTGenericPluginException 
										  reason:@"Unable to load inspector from bundle, more than one unbound object controller found." 
										userInfo:[NSDictionary dictionaryWithObject:identifier forKey:@"plugin"]];
					result = NO;
				}
				else
				{
					*objectController = anObject;
					[*objectController setContent:plugin];
				}
			}
			else if ([anObject isKindOfClass:[NSView class]])
			{
				if (*inspectorView)	// Already thinks it has an inspector view? Could be a problem!
				{
					NSString *identifier = [[plugin inspectorNibBundle] bundleIdentifier];
					[self raiseExceptionWithName:kKTGenericPluginException 
										  reason:@"Unable to load inspector from bundle, more than one view object found." 
										userInfo:[NSDictionary dictionaryWithObject:identifier forKey:@"plugin"]];
					result = NO;
				}
				else
				{
					*inspectorView = anObject;
				}
			}
		}
	}
	
	return result;
}

@end
