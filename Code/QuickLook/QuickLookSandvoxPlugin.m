//
//  QuickLookSandvoxPlugin.m
//  SandvoxQuickLook
//
//  Created by Mike on 20/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "QuickLookSandvoxPlugin.h"


@interface QuickLookSandvoxPlugin (Private)

+ (Class)registeredPluginClassForFileExtension:(NSString *)extension;

+ (QuickLookSandvoxPlugin *)pluginForPath:(NSString *)path;
+ (void)registerPlugin:(QuickLookSandvoxPlugin *)plugin forPath:(NSString *)path;
+ (NSMutableDictionary *)_pluginsByPath;

+ (QuickLookSandvoxPlugin *)registeredPluginForIdentifier:(NSString *)identifier;
+ (NSMutableDictionary *)_pluginsByIdentifier;
+ (NSComparisonResult)comparePluginPaths:(NSString *)pathA :(NSString *)pathB;

@end


@implementation QuickLookSandvoxPlugin

#pragma mark -
#pragma mark Accessing Plugins

+ (id)pluginWithPath:(NSString *)path
{
	QuickLookSandvoxPlugin *result = nil;
	
	path = [path stringByResolvingSymlinksInPath];
	QuickLookSandvoxPlugin *plugin = [self pluginForPath:path];
	
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
	QuickLookSandvoxPlugin *result = [self pluginWithPath:path];
	return result;
}

/*	Hopefully there'll already be a plugin registered for the identifier. If so, return it.
 *	If not, fall back to NSBundle's methods.
 */
+ (id)pluginWithIdentifier:(NSString *)identifier
{
	QuickLookSandvoxPlugin *result = nil;
	
	QuickLookSandvoxPlugin *plugin = [self registeredPluginForIdentifier:identifier];
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

/*	We cheat here and always return self. The more intelligent subclass, KTAppPlugin will actually
 *	return the right class.
 */
+ (Class)registeredPluginClassForFileExtension:(NSString *)extension
{
	Class result = nil;
	
	static NSSet *pluginExtensions;
	if (!pluginExtensions)
	{
		pluginExtensions = [[NSSet alloc] initWithObjects:@"svxDesign", @"svxElement", @"svxIndex", @"svxDataSource"];
	}
	
	if ([pluginExtensions containsObject:extension])
	{
		result = self;
	}
	
	return result;
}

#pragma mark -
#pragma mark Path Registration

+ (QuickLookSandvoxPlugin *)pluginForPath:(NSString *)path
{
	QuickLookSandvoxPlugin *result = [[self _pluginsByPath] objectForKey:path];
	return result;
}

+ (void)registerPlugin:(QuickLookSandvoxPlugin *)plugin forPath:(NSString *)path
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

+ (QuickLookSandvoxPlugin *)registeredPluginForIdentifier:(NSString *)identifier
{
	return [[self _pluginsByIdentifier] objectForKey:identifier];
}

+ (void)registerPlugin:(QuickLookSandvoxPlugin *)plugin forIdentifier:(NSString *)identifier
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
		
		[buffer addObject:[[NSBundle mainBundle] builtInPlugInsPath]];
		[buffer addObject:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Designs"]];
		
		result = [buffer copy];
	}
	
	return result;
}

/*	For QuickLook we're not checking version, just location. KTAppPlugin will do both.
 */
+ (QuickLookSandvoxPlugin *)preferredPlugin:(QuickLookSandvoxPlugin *)pluginA :(QuickLookSandvoxPlugin *)pluginB
{
	QuickLookSandvoxPlugin *result = nil;
	
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
		[QuickLookSandvoxPlugin registerPlugin:self forPath:[[bundle bundlePath] stringByResolvingSymlinksInPath]];
		
		
		// Register the identfier if we are the best match for it
		NSString *identifier = [bundle bundleIdentifier]; 
		QuickLookSandvoxPlugin *bestPlugin = self;
		
		QuickLookSandvoxPlugin *otherMatch = [QuickLookSandvoxPlugin registeredPluginForIdentifier:identifier];
		if (otherMatch)
		{
			bestPlugin = [[self class] preferredPlugin:self :otherMatch];
		}
		
		[QuickLookSandvoxPlugin registerPlugin:bestPlugin forIdentifier:identifier];
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
