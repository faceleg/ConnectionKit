//
//  KTPluginDelegatesManager.m
//  Marvel
//
//  Created by Mike on 08/11/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTPluginDelegatesManager.h"

#import "KTAbstractElement.h"
#import "KTAbstractPluginDelegate.h"
#import "NSString+Karelia.h"
#import "NSManagedObject+KTExtensions.h"


@implementation KTPluginDelegatesManager

#pragma mark -
#pragma mark Init

- (id)init
{
	[super init];
	
	myPluginDelegates = [[NSMutableDictionary alloc] init];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(managedObjectContextObjectsDidChange:)
												 name:NSManagedObjectContextObjectsDidChangeNotification
											   object:nil];
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	// To keep the UI happy, we want to detach all delegates fromt their plugin
	[[myPluginDelegates allValues] makeObjectsPerformSelector:@selector(setDelegateOwner:)
												   withObject:nil];
												   
	[myPluginDelegates release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Delegates

- (KTAbstractPluginDelegate *)delegateForPlugin:(KTAbstractElement *)plugin
{
	NSString *pluginID = [plugin uniqueID];
	KTAbstractPluginDelegate *result = [myPluginDelegates objectForKey:pluginID];
	
	// Load the plugin delegate if it hasn't already been loaded
	if (!result)
	{
		Class delegateClass = [[[plugin plugin] bundle] principalClass];
		if (delegateClass)
		{
			result = [[delegateClass alloc] init];
            OBASSERTSTRING(result, @"plugin delegate cannot be nil!");
			
			[result setDelegateOwner:plugin];
			[myPluginDelegates setObject:result forKey:pluginID];
			
			// Let the delegate know that it's awoken
			if ([result respondsToSelector:@selector(awakeFromBundleAsNewlyCreatedObject:)])
			{
				[result awakeFromBundleAsNewlyCreatedObject:[plugin isTemporaryObject]];
			}
			
			[result release];
		}
	}
	
	return result;
}

- (void)removeDelegateForPlugin:(KTAbstractElement *)plugin
{
	[[plugin delegate] setDelegateOwner:nil];
	[myPluginDelegates removeObjectForKey:[plugin uniqueID]];
}

#pragma mark -
#pragma mark Managed Object Context

/*	We keep an eye on the managed object context in order to disconnect a delegate from its plugin if
 *	the plugin is deleted.
 */
- (void)managedObjectContextObjectsDidChange:(NSNotification *)notification
{
	NSSet *deletedObjects = [[notification userInfo] objectForKey:NSDeletedObjectsKey];
	NSEnumerator *deletedObjectsEnumerator = [deletedObjects objectEnumerator];
	id aDeletedObject;
	
	while (aDeletedObject = [deletedObjectsEnumerator nextObject])
	{
		if ([aDeletedObject isKindOfClass:[KTAbstractElement class]] &&
			[myPluginDelegates objectForKey:[(KTAbstractElement *)aDeletedObject uniqueID]])
		{
			[self removeDelegateForPlugin:aDeletedObject];
		}
	}
}

@end
