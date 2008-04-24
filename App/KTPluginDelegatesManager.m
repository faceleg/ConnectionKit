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

- (id)init
{
	[super init];
	myPluginDelegates = [[NSMutableDictionary alloc] init];
	return self;
}

- (void)dealloc
{
	// To keep the UI happy, we want to detach all delegates fromt their plugin
	[[myPluginDelegates allValues] makeObjectsPerformSelector:@selector(setDelegateOwner:)
												   withObject:nil];
												   
	[myPluginDelegates release];
	
	[super dealloc];
}

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

@end
