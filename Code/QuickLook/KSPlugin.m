//
//  KSPlugin.m
//  SandvoxQuickLook
//
//  Created by Mike on 20/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KSPlugin.h"


@interface KSPlugin

+ (void)searchForPlugins;
+ (Class)registeredPluginClassForFileExtension:(NSString *)extension;

+ (KSPlugin *)pluginForPath:(NSString *)path;
+ (void)registerPlugin:(KSPlugin *)plugin forPath:(NSString *)path;
+ (NSMutableDictionary *)_pluginsByPath;

+ (KSPlugin *)registeredPluginForIdentifier:(NSString *)identifier;
+ (NSMutableDictionary *)_pluginsByIdentifier;
+ (NSComparisonResult)comparePluginPaths:(NSString *)pathA :(NSString *)pathB;

@end


@implementation KSPlugin

#pragma mark -
#pragma mark Accessing Plugins

+ (id)pluginWithPath:(NSString *)path
{
	KSPlugin *result = nil;
	
	path = [path stringByResolvingSymlinksInPath];
	KSPlugin *plugin = [self pluginForPath:path];
	
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
	KSPlugin *result = [self pluginWithPath:path];
	return result;
}

/*	Hopefully there'll already be a plugin registered for the identifier. If so, return it.
 *	If not, fall back to NSBundle's methods.
 */
+ (id)pluginWithIdentifier:(NSString *)identifier
{
	// Ensure all reasonably found plugins have been loaded
	static BOOL sHaveSearchedForPlugins;
	static NSDate *sLastPluginSearchDate;
	if (!sHaveSearchedForPlugins || (-[sLastPluginSearchDate timeIntervalSinceNow]) > (4 * 60.0))
	{
		[self searchForPlugins];
		
		sHaveSearchedForPlugins = YES;
		[sLastPluginSearchDate release];	sLastPluginSearchDate = [[NSDate alloc] init];
	}
	
	// Use an existing plugin object when possible
	KSPlugin *result = nil;
	KSPlugin *plugin = [self registeredPluginForIdentifier:identifier];
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
#pragma mark File Extensions

/*	We cheat here and always return self. The more intelligent subclass, KTAppPlugin will actually
 *	return the right class.
 */
+ (Class)registeredPluginClassForFileExtension:(NSString *)extension
{
	Class result = nil;
	
	static NSSet *pluginExtensions;
	if (!pluginExtensions)
	{
		pluginExtensions = [[NSSet alloc] initWithObjects:@"svxDesign",
														  @"svxElement",
														  @"svxIndex", nil];
	}
	
	if ([pluginExtensions containsObject:extension])
	{
		result = self;
	}
	
	return result;
}

/*	Run through all plugin search paths and load as many plugins as possible
 */
+ (void)searchForPlugins
{
	NSArray *pluginSearchPaths = [self pluginSearchPaths];
	NSEnumerator *searchPathEnumerator = [pluginSearchPaths objectEnumerator];
	NSString *aSearchPath;
	
	while (aSearchPath = [searchPathEnumerator nextObject])
	{
		NSEnumerator *pathContentsEnumerator =
			[[[NSFileManager defaultManager] directoryContentsAtPath:aSearchPath] objectEnumerator];
		NSString *aFilename;
		
		while (aFilename = [pathContentsEnumerator nextObject])
		{
			NSString *aPath = [aSearchPath stringByAppendingPathComponent:aFilename];
			[self pluginWithPath:aPath];
		}
	}
}

#pragma mark -
#pragma mark Path Registration

+ (KSPlugin *)pluginForPath:(NSString *)path
{
	KSPlugin *result = [[self _pluginsByPath] objectForKey:path];
	return result;
}

+ (void)registerPlugin:(KSPlugin *)plugin forPath:(NSString *)path
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

+ (KSPlugin *)registeredPluginForIdentifier:(NSString *)identifier
{
	return [[self _pluginsByIdentifier] objectForKey:identifier];
}

+ (void)registerPlugin:(KSPlugin *)plugin forIdentifier:(NSString *)identifier
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
 *	This method searches in /Designs and /PlugIns
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
			NSString *sandvoxPath = [[aPath stringByAppendingPathComponent:@"Sandvox"] stringByResolvingSymlinksInPath];
			
			NSString *pluginsPath = [[sandvoxPath stringByAppendingPathComponent:@"PlugIns"]
										stringByResolvingSymlinksInPath];
			
			NSString *designsPath = [[sandvoxPath stringByAppendingPathComponent:@"Designs"]
										stringByResolvingSymlinksInPath];
			
			[buffer addObject:pluginsPath];
			[buffer addObject:designsPath];
			[buffer addObject:sandvoxPath];
		}
		
		// Since the plugin is running insied QuickLook, +mainBundle does not work.
		NSString *sandvoxPath =
			[[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:@"com.karelia.Sandvox"];
		
		[buffer addObject:[[NSBundle bundleWithPath:sandvoxPath] builtInPlugInsPath]];
		[buffer addObject:[sandvoxPath stringByAppendingPathComponent:@"Contents/Designs"]];
		
		result = [buffer copy];
	}
	
	return result;
}

/*	For QuickLook we're not checking version, just location. KTAppPlugin will do both.
 */
+ (KSPlugin *)preferredPlugin:(KSPlugin *)pluginA :(KSPlugin *)pluginB
{
	KSPlugin *result = nil;
	
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
		[KSPlugin registerPlugin:self forPath:[[bundle bundlePath] stringByResolvingSymlinksInPath]];
		
		
		// Register the identfier if we are the best match for it
		NSString *identifier = [bundle bundleIdentifier]; 
		KSPlugin *bestPlugin = self;
		
		KSPlugin *otherMatch = [KSPlugin registeredPluginForIdentifier:identifier];
		if (otherMatch)
		{
			bestPlugin = [[self class] preferredPlugin:self :otherMatch];
		}
		
		[KSPlugin registerPlugin:bestPlugin forIdentifier:identifier];
    }

    return self;
}

- (void)dealloc
{
    [myBundle release];
    [super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (NSBundle *)bundle { return myBundle; }

@end
