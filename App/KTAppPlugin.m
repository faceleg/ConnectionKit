//
//  KTAppPlugin.m
//  Marvel
//
//  Created by Mike on 26/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTAppPlugin.h"


@interface KTAppPlugin (Private)
+ (KTAppPlugin *)pluginForPath:(NSString *)path;
+ (void)registerPlugin:(KTAppPlugin *)plugin forPath:(NSString *)path;
+ (NSMutableDictionary *)_pluginsByPath;
@end


@implementation KTAppPlugin

#pragma mark -
#pragma mark Accessing Plugins

+ (id)pluginWithPath:(NSString *)path
{
	KTAppPlugin *result = nil;
	
	path = [path stringByStandardizingPath];
	KTAppPlugin *plugin = [self pluginForPath:path];
	
	if (!plugin)
	{
		NSBundle *bundle = [NSBundle bundleWithPath:path];
		Class pluginClass = [self registeredPluginClassForFileExtension:[path pathExtension]];
		plugin = [[[pluginClass alloc] initWithBundle:bundle] autorelease];
	}
	
	// If the plugin does not match the class requested, return nil
	if ([plugin isKindOfClass:self])
	{
		result = plugin;
	}
	
	return result;
}

+ (id)pluginWithBundle:(NSBundle *)bundle
{
	NSString *path = [bundle bundlePath];
	KTAppPlugin *result = [self pluginWithPath:path];
	return result;
}

+ (id)pluginWithIdentifier:(NSString *)identifier
{
	NSBundle *bundle = [NSBundle bundleWithIdentifier:identifier];
	KTAppPlugin *result = [self pluginWithBundle:bundle];
	return result;
}

#pragma mark support

+ (KTAppPlugin *)pluginForPath:(NSString *)path
{
	KTAppPlugin *result = [[self _pluginsByPath] objectForKey:path];
	return result;
}

+ (void)registerPlugin:(KTAppPlugin *)plugin forPath:(NSString *)path
{
	NSParameterAssert(plugin);
	[[self _pluginsByPath] setObject:plugin forKey:path];
}

+ (NSMutableDictionary *)_pluginsByPath
{
	static NSMutableDictionary *result = nil;
	
	if (!result)
	{
		result = [[NSMutableDictionary alloc] init];
	}
	
	return result;
}

#pragma mark -
#pragma mark Plugin Registration

+ (NSMutableDictionary *)_registeredPluginClasses
{
	static NSMutableDictionary *sRegisteredPluginClasses;
	
	if (!sRegisteredPluginClasses)
	{
		sRegisteredPluginClasses = [[NSMutableDictionary alloc] initWithCapacity:3];
	}
	
	return sRegisteredPluginClasses;
}

+ (Class)registeredPluginClassForFileExtension:(NSString *)extension
{
	Class result = [[self _registeredPluginClasses] objectForKey:extension];
	return result;
}

+ (void)registerPluginClass:(Class)pluginClass forFileExtension:(NSString *)extension
{
	[[self _registeredPluginClasses] setObject:pluginClass forKey:extension];
}

#pragma mark -
#pragma mark Init & Dealloc

- (id)initWithBundle:(NSBundle *)bundle
{
    self = [super init];
    
	if (self)
	{
        myBundle = [bundle retain];
		
		// Register the path
		[KTAppPlugin registerPlugin:self forPath:[[bundle bundlePath] stringByStandardizingPath]];
    }

    return self;
}

- (void)dealloc
{
    [myBundle release];
    [super dealloc];
}

#pragma mark -
#pragma mark Description

- (NSString *)description
{
	NSString *result = [[super description] stringByAppendingFormat:@" %@", [[self bundle] bundlePath]];
	return result;
}

#pragma mark -
#pragma mark Accessors

- (NSBundle *)bundle { return myBundle; }

/*	Eventually I think we should move to UTIs for plugin typing
 */
- (NSString *)pluginType
{
	NSString *result = [[[self bundle] bundlePath] pathExtension];
	return result;
}

- (NSString *)version
{
	return [[self bundle] version];
}

- (NSString *)identifier
{
	return [[self bundle] bundleIdentifier];
}

- (NSString *)minimumAppVersion
{
    id retVal = [[self bundle] objectForInfoDictionaryKey:@"KTMinimumAppVersion"];
    return retVal;
}

#pragma mark -
#pragma mark Plugin Properties

/*	Simple method that looks in the bundle's Info.plist for the specified key. 
 *	If none is found, returns the corresponding value from the classes defaults.
 */
- (id)pluginPropertyForKey:(NSString *)key
{
	id result = [[self bundle] objectForInfoDictionaryKey:key];
	
	if (!result)
	{
		result = [self defaultPluginPropertyForKey:key];
	}
	
	return result;
}

- (id)defaultPluginPropertyForKey:(NSString *)key
{
	return nil;
}

@end
