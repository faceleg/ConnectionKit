//
//  KTAppPlugin.m
//  Marvel
//
//  Created by Mike on 26/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTAppPlugin.h"

#import "NSBundle+Karelia.h"


@interface KTAppPlugin (Private)
+ (void)registerPlugin:(KTAppPlugin *)plugin forPath:(NSString *)path;
@end


@implementation KTAppPlugin

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
#pragma mark Identifier Registration

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
			NSString *sandvoxPath = [[aPath stringByAppendingPathComponent:@"Sandvox"] stringByResolvingSymlinksInPath];
			
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

+ (QuickLookSandvoxPlugin *)preferredPlugin:(QuickLookSandvoxPlugin *)pluginA :(QuickLookSandvoxPlugin *)pluginB
{
	QuickLookSandvoxPlugin *result = nil;
	
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
			result = [super preferredPlugin:pluginA :pluginB];
		}
	}
	
	return result;
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
