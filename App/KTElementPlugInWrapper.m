//
//  KTElementPlugInWrapper.m
//  Marvel
//
//  Created by Mike on 26/01/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import "KTElementPlugInWrapper.h"

#import "SVPlugInGraphicFactory.h"
#import "KT.h"

#import "NSBundle+Karelia.h"
#import "NSString+Karelia.h"

#import "Registration.h"

@implementation KTElementPlugInWrapper

#pragma mark Init & Dealloc

+ (void)load
{
	[self registerPluginClass:[self class] forFileExtension:kKTElementExtension];
}

/*	We only want to load 2.0 style plug-ins
 */
+ (BOOL)validateBundle:(NSBundle *)aCandidateBundle
{
	BOOL result = NO;
	
	NSString *minVersion = [aCandidateBundle objectForInfoDictionaryKey:@"SVMinimumAppVersion"];
	if (minVersion)
	{
        // It's a 2.0-style plug-in. Is the app suitable to load it?
		float floatMinVersion = [minVersion floatVersion];
		if (floatMinVersion >= 2.0f)
		{
			result = YES;
		}
        else
        {
            NSLog(@"Not loading %@ as it has too low a minimum app version", [aCandidateBundle bundlePath]);
        }
	}
    else
    {
        // No minimum app version specified; does it look to be a Sandvox 1 plug-in?
        result = YES;
        
        if ([aCandidateBundle objectForInfoDictionaryKey:@"KSMinimumAppVersion"] ||
            [aCandidateBundle objectForInfoDictionaryKey:@"KTMinimumAppVersion"])
        {
            result = NO;
            NSLog(@"Not loading %@ as it looks to be a plug-in for Sandvox 1", [aCandidateBundle bundlePath]);
        }
    }
	
	return result;
}

- (void)dealloc
{
    [_factory release];
	
	[super dealloc];
}

#pragma mark Properties

- (SVGraphicFactory *)graphicFactory;
{
    if (!_factory)
    {
        _factory = [[SVPlugInGraphicFactory alloc] initWithBundle:[self bundle]];
    }
    return _factory;
}

- (KTPluginCategory)category { return [[self pluginPropertyForKey:@"KTCategory"] intValue]; }

- (id)defaultPluginPropertyForKey:(NSString *)key;
{
	if ([key isEqualToString:@"KTElementAllowsIntroduction"])
	{
		return [NSNumber numberWithBool:NO];
	}
	else if ([key isEqualToString:@"KTElementSupportsPageUsage"])
	{
		return [NSNumber numberWithBool:NO];
	}
	else if ([key isEqualToString:@"KTElementSupportsPageletUsage"])
	{
		return [NSNumber numberWithBool:YES];
	}
	else if ([key isEqualToString:@"KTPageAllowsCallouts"])
	{
		return [NSNumber numberWithBool:NO];
	}
	else if ([key isEqualToString:@"KTPageShowSidebar"])
	{
		return [NSNumber numberWithBool:YES];
	}
	else if ([key isEqualToString:@"KTPageAllowsNavigation"])
	{
		return [NSNumber numberWithBool:YES];
	}
	else if ([key isEqualToString:@"KTPageletCanHaveTitle"])
	{
		return [NSNumber numberWithBool:YES];
	}
	else if ([key isEqualToString:@"KTPageSidebarChangeable"])
	{
		return [NSNumber numberWithBool:YES];
	}
	else if ([key isEqualToString:@"KTPageSeparateInspectorSegment"])
	{
		return [NSNumber numberWithBool:NO];
	}
	else if ([key isEqualToString:@"KTPageName"] || [key isEqualToString:@"KTPageletName"])
	{
		return [self pluginPropertyForKey:@"KTPluginName"];
	}
	else if ([key isEqualToString:@"KTPluginUntitledName"])
	{
		return @"";
	}
	else if ([key isEqualToString:@"KTPageUntitledName"] || [key isEqualToString:@"KTPageletUntitledName"])
	{
		return [self pluginPropertyForKey:@"KTPluginUntitledName"];
	}
	else if ([key isEqualToString:@"SVPlugInDescription"])
	{
		return @"";
	}
	else if ([key isEqualToString:@"KTPageDescription"] || [key isEqualToString:@"KTPageletDescription"])
	{
		return [self pluginPropertyForKey:@"SVPlugInDescription"];
	}
	else if ([key isEqualToString:@"KTPageNibFile"])
	{
		return [self pluginPropertyForKey:@"KTPluginNibFile"];
	}
	else if ([key isEqualToString:@"KTPluginPriority"])
	{
		return [NSNumber numberWithUnsignedInt:5];
	}
	else
	{
		return [super defaultPluginPropertyForKey:key];
	}
}

/*
 
 Maybe if I override this, I can easily get a list sorted by priority
 
- (NSComparisonResult)compareTitles:(KSPlugInWrapper *)aPlugin;
{
	return [[self title] caseInsensitiveCompare:[aPlugin title]];
}
*/

#pragma mark -
#pragma mark Plugins List

/*	Returns all registered plugins that are either:
 *		A) Of the svxPage plugin type
 *		B) Of the svxElement plugin type and support page usage
 */
+ (NSSet *)pagePlugins
{
	NSDictionary *pluginDict = [KSPlugInWrapper pluginsWithFileExtension:kKTElementExtension];
	NSMutableSet *buffer = [NSMutableSet setWithCapacity:[pluginDict count]];
	
	NSEnumerator *pluginsEnumerator = [pluginDict objectEnumerator];
	KSPlugInWrapper *aPlugin;
	while (aPlugin = [pluginsEnumerator nextObject])
	{
		if ([[aPlugin pluginPropertyForKey:@"KTElementSupportsPageUsage"] boolValue])
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
+ (NSSet *)pageletPlugins
{
	NSDictionary *pluginDict = [KSPlugInWrapper pluginsWithFileExtension:kKTElementExtension];
	NSMutableSet *buffer = [NSMutableSet setWithCapacity:[pluginDict count]];
	
	NSEnumerator *pluginsEnumerator = [pluginDict objectEnumerator];
	KSPlugInWrapper *aPlugin;
	while (aPlugin = [pluginsEnumerator nextObject])
	{
		if ([[aPlugin pluginPropertyForKey:@"KTElementSupportsPageletUsage"] boolValue])
		{
			[buffer addObject:aPlugin];
		}
	}
	
	NSSet *result = [NSSet setWithSet:buffer];
	return result;
}

#pragma mark Collection Presets

+ (NSSet *)collectionPresets;
{
    NSMutableSet *result = [NSMutableSet set];
	
    
    // Go through and get the localized names of each bundle, and put into a dict keyed by name
    NSDictionary *plugins = [KSPlugInWrapper pluginsWithFileExtension:kKTElementExtension];
    NSEnumerator *enumerator = [plugins objectEnumerator];	// go through each plugin.
    KTElementPlugInWrapper *plugin;
    
	while (plugin = [enumerator nextObject])
	{
		NSBundle *bundle = [plugin bundle];
		
		NSArray *presets = [bundle objectForInfoDictionaryKey:@"SVIndexMasters"];
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
            if (priority > 0)	// don't add zero-priority items to menu!
            {                
                NSMutableDictionary *newPreset = [presetDict mutableCopy];
                [newPreset setObject:[bundle bundleIdentifier] forKey:@"KTPresetIndexBundleIdentifier"];
                
                [result addObject:newPreset];
                [newPreset release];
            }
		}
	}
    return result;
}

@end
