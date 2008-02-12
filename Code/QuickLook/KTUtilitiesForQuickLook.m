//
//  KTUtilitiesForQuickLook.m
//  SandvoxQuickLook
//
//  Created by Dan Wood on 11/29/07.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTUtilitiesForQuickLook.h"
#import "NSString+QuickLook.h"
#import "NSBundle+QuickLook.h"

@implementation KTUtilitiesForQuickLook

/*!	Get plug-ins of some given extension.
 For the app wrapper, use the specified "sister directory" of the plug-ins path.
 (If not specified, use the built-in plug-ins path.)
 We also look in Application Support/Sandvox at all levels
 and also, if the directory is specified, that subdir of the above, e.g. Application Support/Sandvox/Designs
 It's optional to be in the specified sub-directory.
 
 This is used for plugin bundles, but also for designs
 */


+ (NSDictionary *)pluginsWithExtension:(NSString *)extension sisterDirectory:(NSString *)dirPath
{
    NSMutableDictionary *pluginDict = [NSMutableDictionary dictionary];
    
	NSString *appPath = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:@"com.karelia.Sandvox"];
	NSBundle *appBundle = [[[NSBundle alloc] initWithPath:appPath] autorelease];
	float appVersion = [[appBundle version] floatVersion];
    NSString *builtInPlugInsPath = [appBundle builtInPlugInsPath];
    
    if ( nil != dirPath & ![dirPath isEqualToString:@"Plugins"] )	// Sister directory of plugins?
	{
		// go up out of plug-ins, down into specified directory
        builtInPlugInsPath = [[builtInPlugInsPath stringByDeletingLastPathComponent]
							  stringByAppendingPathComponent:dirPath];
    }
	else
	{
		dirPath = @"PlugIns";		// for looking in app support folder
	}
    
	NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSAllDomainsMask,YES);
	NSString *subDir = [NSString pathWithComponents:
						[NSArray arrayWithObjects:@"Sandvox", dirPath, nil]];
	
	// Add this sub-dir to each path, along with just the path without the subdir
	NSEnumerator *theEnum = [libraryPaths objectEnumerator];
	NSString *libraryPath;
	NSMutableArray *paths = [NSMutableArray array];
	
	while (nil != (libraryPath = [theEnum nextObject]) )
	{
		[paths addObject:[libraryPath stringByAppendingPathComponent:subDir]];
		[paths addObject:[libraryPath stringByAppendingPathComponent:@"Sandvox"]];
	}
	
	// Add the app's built-in plug-in path too.
	[paths addObject:builtInPlugInsPath];
	
	// Now go through each folder, backwards -- items in more local user
	// folder override built-in ones.
    NSEnumerator *pathsEnumerator = [paths reverseObjectEnumerator];
    NSString *path;
    
    while ( path = [pathsEnumerator nextObject] ) {
		//		NSLog(@"Plugins Checking: %@ for *.%@", path, extension);
        NSEnumerator *pluginsEnumerator = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
        NSString *pluginName;
        while ( pluginName = [pluginsEnumerator nextObject] ) {
            NSString *pluginPath = [path stringByAppendingPathComponent:pluginName];
            if ( [[pluginPath pathExtension] isEqualToString:extension] ) {
                NSBundle *pluginBundle = [NSBundle bundleWithPath:pluginPath];
                if ( nil != pluginBundle ) 
				{
					[pluginBundle principalClass]; // fix for CoreData via bbum WWDC 2005
					NSString *identifier = [pluginBundle bundleIdentifier];
					if (nil == identifier)
					{
						identifier = pluginName;
					}
					
					// Only use an "override" if its version is >= the built-in version.
					// This way, we can update the version with the app, and it supercedes any
					// specially installed versions.
					NSBundle *alreadyInstalledBundle = [pluginDict objectForKey:identifier];
					if (nil != alreadyInstalledBundle
						|| [[pluginBundle version] floatVersion] >= [[alreadyInstalledBundle version] floatVersion])
					{
						if (nil == [pluginBundle minimumAppVersion]
							|| [[pluginBundle minimumAppVersion] floatVersion] <= appVersion)		// plugin's version must be less/equal than app version, not more!
						{
							[pluginDict setObject:pluginBundle forKey:identifier];
							
							if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ShowSearchPaths"])
							{
								// ALWAYS show an override, regardless of preference, to help with support.  But don't do for DEBUG since it's just clutter to us!
								NSLog(@"Found %@ in %@/", pluginName, [path stringByAbbreviatingWithTildeInPath]);
							}
						}
						else
						{
							NSLog(@"Not loading %@, application version %@ is required",
								  [pluginPath stringByAbbreviatingWithTildeInPath], [pluginBundle minimumAppVersion]);
						}
					}
                }
            }
        }
    }
    
    if ( 0 == [pluginDict count] )
	{
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ShowSearchPaths"])
		{
			// Show item #1 in the list which is going to be the ~/Libary/Application Support/Sandvox SANS "PlugIns" or "Designs"?
			NSLog(@"Searched for '.%@' plugins in %@/", extension, [[paths objectAtIndex:1] stringByAbbreviatingWithTildeInPath]);
		}
		return nil;
    }
    
    return [NSDictionary dictionaryWithDictionary:pluginDict];
}


@end
