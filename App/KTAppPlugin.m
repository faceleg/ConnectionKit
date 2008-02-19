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

+ (KTAppPlugin *)registeredPluginForIdentifier:(NSString *)identifier;
+ (NSMutableDictionary *)_pluginsByIdentifier;

+ (NSArray *)pluginSearchPaths;
+ (KTAppPlugin *)preferredPlugin:(KTAppPlugin *)pluginA :(KTAppPlugin *)pluginB;
+ (NSComparisonResult)comparePluginPaths:(NSString *)pathA :(NSString *)pathB;

@end


@implementation KTAppPlugin

#pragma mark -
#pragma mark Accessing Plugins

+ (id)pluginWithPath:(NSString *)path
{
	KTAppPlugin *result = nil;
	
	path = [path stringByResolvingSymlinksInPath];
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

/*	Hopefully there'll already be a plugin registered for the identifier. If so, return it.
 *	If not, fall back to NSBundle's methods.
 */
+ (id)pluginWithIdentifier:(NSString *)identifier
{
	KTAppPlugin *result = nil;
	
	KTAppPlugin *plugin = [self registeredPluginForIdentifier:identifier];
	if (!plugin)
	{
		plugin = [self pluginWithBundle:[NSBundle bundleWithIdentifier:identifier]];
	}
	
	// If the plugin does not match the class requested, return nil
	if ([plugin isKindOfClass:self])
	{
		result = plugin;
	}
	
	return result;
}

#pragma mark -
#pragma mark Class Registration

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
#pragma mark Path Registration

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
#pragma mark Identifier Registration

+ (KTAppPlugin *)registeredPluginForIdentifier:(NSString *)identifier
{
	return [[self _pluginsByIdentifier] objectForKey:identifier];
}

+ (void)registerPlugin:(KTAppPlugin *)plugin forIdentifier:(NSString *)identifier
{
	[[self _pluginsByIdentifier] setObject:plugin forKey:identifier];
}

+ (NSMutableDictionary *)_pluginsByIdentifier
{
	static NSMutableDictionary *result = nil;
	
	if (!result)
	{
		result = [[NSMutableDictionary alloc] init];
	}
	
	return result;
}

/*	The paths to search for plugins in. index 0 is the best location.
 *	KTDesign overrides this method to search in /Designs rather than /PlugIns
 */
+ (NSArray *)pluginSearchPaths
{
	static NSArray *result;
	
	if (!result)
	{
		NSMutableArray *buffer = [NSMutableArray array];
		
		NSArray *basePaths =
			NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSAllDomainsMask, YES);
		
		NSEnumerator *pathsEnumerator = [basePaths objectEnumerator];
		NSString *aPath;
		while (aPath = [pathsEnumerator nextObject])
		{
			// It is very important to standardize paths here in order to catch symlinks
			NSString *sandvoxPath = [[aPath stringByAppendingPathComponent:
										[NSApplication applicationName]]
											stringByResolvingSymlinksInPath];
			
			NSString *pluginsPath = [[sandvoxPath stringByAppendingPathComponent:@"PlugIns"]
										stringByResolvingSymlinksInPath];
			
			[buffer addObject:pluginsPath];
			[buffer addObject:sandvoxPath];
		}
		
		[buffer addObject:[[NSBundle mainBundle] builtInPlugInsPath]];
		
		result = [buffer copy];
	}
	
	return result;
}

+ (KTAppPlugin *)preferredPlugin:(KTAppPlugin *)pluginA :(KTAppPlugin *)pluginB
{
	KTAppPlugin *result = nil;
	
	// First check by version
	NSComparisonResult versionComparison =
		SUStandardVersionComparison([[pluginA bundle] version], [[pluginB bundle] version]);
	
	switch (versionComparison)
	{
		case NSOrderedDescending:
			result = pluginA;
			break;
		case NSOrderedAscending:
			result = pluginB;
			break;
		
		case NSOrderedSame:
		{
			// Have to compare by path
			NSComparisonResult pathComparison =
				[self comparePluginPaths:[[pluginA bundle] bundlePath] :[[pluginB bundle] bundlePath]];
			
			if (pathComparison == NSOrderedAscending)
			{
				result = pluginB;
			}
			else
			{
				result = pluginA;
			}
		}
	}
	
	return result;
}

+ (NSComparisonResult)comparePluginPaths:(NSString *)pathA :(NSString *)pathB
{
	NSString *dirA = [pathA stringByDeletingLastPathComponent];
	NSString *dirB = [pathB stringByDeletingLastPathComponent];
	
	unsigned indexA = [[self pluginSearchPaths] indexOfObject:dirA];
	unsigned indexB = [[self pluginSearchPaths] indexOfObject:dirB];
	
	if (indexA == indexB)
	{
		return NSOrderedSame;
	}
	else if (indexA == NSNotFound)
	{
		return NSOrderedDescending;
	}
	else if (indexB == NSNotFound)
	{
		return NSOrderedAscending;
	}
	else if (indexA < indexB)
	{
		return NSOrderedDescending;
	}
	else
	{
		return NSOrderedAscending;
	}
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
		[KTAppPlugin registerPlugin:self forPath:[[bundle bundlePath] stringByResolvingSymlinksInPath]];
		
		
		// Register the identfier if we are the best match for it
		NSString *identifier = [bundle bundleIdentifier]; 
		KTAppPlugin *bestPlugin = self;
		
		KTAppPlugin *otherMatch = [KTAppPlugin registeredPluginForIdentifier:identifier];
		if (otherMatch)
		{
			bestPlugin = [[self class] preferredPlugin:self :otherMatch];
		}
		
		[KTAppPlugin registerPlugin:bestPlugin forIdentifier:identifier];
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
