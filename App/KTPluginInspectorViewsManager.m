//
//  KTPluginInspectorViewsManager.m
//  Marvel
//
//  Created by Mike on 28/08/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "KTPluginInspectorViewsManager.h"

#import "NSDictionary+Karelia.h"
#import "NSException+Karelia.h"
#import "NSObject+Karelia.h"


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
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(managedObjectContextObjectsDidChange:)
												 name:NSManagedObjectContextObjectsDidChangeNotification
											   object:nil];
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[self removeAllPluginInspectorViews];
    
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
	NSView *result = [myPluginInspectorViews objectForKey:plugin];
	
	// If no Inspector view is found, try to load the plugin's nib file and return the result of that.
	if (!result)
	{
		[self loadNibFileForPlugin:plugin];
		result = [myPluginInspectorViews objectForKey:plugin];
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
		[NSException raise:kKareliaPluginException 
							  reason:@"Unable to load inspector from bundle, file is missing or not configured right." 
							userInfo:[NSDictionary dictionaryWithObject:[[plugin inspectorNibBundle] bundleIdentifier] forKey:@"plugin"]];
							
		return;
	}
	
    
	// Store the various nib objects
	[myPluginInspectorViews setObject:inspectorView forKey:plugin copyKeyFirst:NO];
	
    if (objectController)
    {
        [myPluginControllers setObject:objectController forKey:plugin copyKeyFirst:NO];
    }
    
	[myPluginTopLevelObjects setObject:topLevelObjects forKey:plugin copyKeyFirst:NO];
	[topLevelObjects makeObjectsPerformSelector:@selector(release)];	// Cancels out the retain from loading the nib
}

/*	Handy if you need to trim memory usage. e.g. you know the plugin will never have its view displayed again.
 */
- (void)removeInspectorViewForPlugin:(id <KTInspectorPlugin>)plugin
{	
	[[myPluginControllers objectForKey:plugin] setContent:nil];
	[myPluginControllers removeObjectForKey:plugin];
	
	[myPluginTopLevelObjects removeObjectForKey:plugin];
	[myPluginInspectorViews removeObjectForKey:plugin];
}

- (void)removeAllPluginInspectorViews
{
    // Disconnect each plugin's controller from its content to ensure nothing tries to access the MOC later.
	[[myPluginControllers allValues] makeObjectsPerformSelector:@selector(setContent:) withObject:nil];
	
    [myPluginControllers removeAllObjects];
    [myPluginInspectorViews removeAllObjects];
    [myPluginTopLevelObjects removeAllObjects];
}

#pragma mark -
#pragma mark Managed Object Context

/*	We keep an eye on the managed object context in order to remove the UI once an element is deleted.
 */
- (void)managedObjectContextObjectsDidChange:(NSNotification *)notification
{
	NSSet *deletedObjects = [[notification userInfo] objectForKey:NSDeletedObjectsKey];
	NSEnumerator *deletedObjectsEnumerator = [deletedObjects objectEnumerator];
	id aDeletedObject;
	
	while (aDeletedObject = [deletedObjectsEnumerator nextObject])
	{
		if ([aDeletedObject conformsToProtocol:@protocol(KTInspectorPlugin)])
		{
			[self removeInspectorViewForPlugin:aDeletedObject];
		}
	}
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
 *	Also then hooks up the object controller to the plug-in.
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
		if (inspectorView)
		{
			*inspectorView = nil;
		}
		if (objectController)
		{
			*objectController = nil;
		}
		NSEnumerator *enumerator = [*topLevelObjects objectEnumerator];
		id anObject;
		
		while (anObject = [enumerator nextObject])
		{
			if ([anObject isKindOfClass:[NSObjectController class]] && ![anObject content])
			{
				if (objectController && *objectController)	// Already thinks it has an object controller? Could be a problem!
				{
					NSString *identifier = [[plugin inspectorNibBundle] bundleIdentifier];
					[NSException raise:kKareliaPluginException 
										  reason:@"Unable to load inspector from bundle, more than one unbound object controller found." 
										userInfo:[NSDictionary dictionaryWithObject:identifier forKey:@"plugin"]];
					result = NO;
				}
				else
				{
					if (objectController)
					{
						*objectController = anObject;
						[*objectController setContent:plugin];
					}
				}
			}
			else if ([anObject isKindOfClass:[NSView class]])
			{
				if (inspectorView)
				{
					if (*inspectorView)	// Already thinks it has an inspector view? Could be a problem!
					{
						NSString *identifier = [[plugin inspectorNibBundle] bundleIdentifier];
						[NSException raise:kKareliaPluginException 
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
	}
	
	return result;
}

@end
