//
//  KTUtilities.m
//  KTComponents
//
//  Copyright (c) 2004 Biophony LLC. All rights reserved.
//

/*
 PURPOSE OF THIS CLASS/CATEGORY:
	Miscellaneous utility functions:
 Plugin utilities
 Unique MAC address to identify this computer
 
 TAXONOMY AND RELATIONSHIP TO OTHER CLASSES:
	x
 
 IMPLEMENTATION NOTES & CAUTIONS:
	x
 
 TO DO:
	???? Should the plugin stuff be moved to the bundle manager?
 
 */

#import "KTUtilities.h"

#import "NSException+Karelia.h"

#import "Debug.h"
#import "KT.h"

#import "KTAppPlugin.h"
#import "KTAbstractHTMLPlugin.h"
#import "KTAbstractElement.h"		// for the benefit of L'izedStringInKTComponents macro
#import "KTManagedObjectContext.h"

#import "NSApplication+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSBundle+KTExtensions.h"
#import "NSError+Karelia.h"
#import "NSString+Karelia.h"

#import <CoreFoundation/CoreFoundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/network/IOEthernetInterface.h>
#import <IOKit/network/IONetworkInterface.h>
#import <IOKit/network/IOEthernetController.h>
#import <Carbon/Carbon.h>
#import <Security/Security.h>


// Global variable, initialize it here is a good place

NSString *gFunnyFileName = nil;

@implementation KTUtilities

+ (void) initialize
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	gFunnyFileName = [[NSString stringWithFormat:@".%@.%@", @"WebKit", @"UTF-16"] retain];
	[pool release];
}
	
#pragma mark Core Data

/*! returns an autoreleased core data stack with file at aStoreURL */
+ (NSManagedObjectContext *)contextWithURL:(NSURL *)aStoreURL model:(NSManagedObjectModel *)aModel
{
	NSError *localError = nil;
	NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:aModel];
	id store = [coordinator addPersistentStoreWithType:NSSQLiteStoreType
										 configuration:nil
												   URL:aStoreURL
											   options:nil
												 error:&localError];
	
	if ( nil == store )
	{
		[coordinator release];
		if ( nil != localError )
		{
			[[NSDocumentController sharedDocumentController] presentError:localError];
		}
		else
		{
			[NSException raise:kKareliaDocumentException 
						format:@"Unable create context from %@", aStoreURL];
		}
		return nil;
	}
	
	//==//NSManagedObjectContext *result = [[NSManagedObjectContext alloc] init];
	KTManagedObjectContext *result = [[KTManagedObjectContext alloc] init];
	[result setPersistentStoreCoordinator:coordinator];
	
	[coordinator release];
	
	return [result autorelease];	
}

/*! returns an autoreleaed model from KTComponents_aVersion.mom */
+ (NSManagedObjectModel *)modelWithVersion:(NSString *)aVersion
{
	// passing in nil for aVersion will return the standard KTComponents model
	
	NSString *resourceName = @"KTComponents";
	if ( nil != aVersion )
	{
		resourceName = [resourceName stringByAppendingString:[NSString stringWithFormat:@"_%@", aVersion]];
	}
	NSString *resourceNameWithExtension = [resourceName stringByAppendingPathExtension:@"mom"];
	
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	NSString *path = [bundle pathForResource:resourceName
									  ofType:@"mom"];
								 //inDirectory:@"Models"];
	NSURL *modelURL = [NSURL fileURLWithPath:path];
	
	if ( nil == modelURL )
	{
		[NSException raise:kKareliaDocumentException 
					format:@"Unable to locate %@", resourceNameWithExtension];
		return nil;
	}
	
	NSManagedObjectModel *result = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
	
	if ( nil == result )
	{
		[NSException raise:kKareliaDocumentException 
					format:@"Unable create model from %@", resourceNameWithExtension];
		return nil;
	}
	
	return [result autorelease];
}

/*! returns an autoreleaed model from KTComponents_aVersion.mom with all
	Class references set to NSManagedObject, except Storage classes
*/
+ (NSManagedObjectModel *)genericModelWithVersion:(NSString *)aVersion
{
	NSManagedObjectModel *model = [self modelWithVersion:aVersion];
	[model retain];
	
	if ( nil != model )
	{
		NSEnumerator *e = [[model entities] objectEnumerator];
		NSEntityDescription *entity = nil;
		while ( entity = [e nextObject] )
		{
			//FIXME: these classes no longer exist, is this method still required?
			if ( ![[entity managedObjectClassName] isEqualToString:@"KTStoredDictionary"] 
				 && ![[entity managedObjectClassName] isEqualToString:@"KTStoredArray"]
				 && ![[entity managedObjectClassName] isEqualToString:@"KTStoredSet"] )
			[entity setManagedObjectClassName:[NSManagedObject className]];
		}
	}
	
	return [model autorelease];
}


#pragma mark Plugin Management

/*!	Get plug-ins of some given extension.
	For the app wrapper, use the specified "sister directory" of the plug-ins path.
	(If not specified, use the built-in plug-ins path.)
	We also look in Application Support/Sandvox at all levels
	and also, if the directory is specified, that subdir of the above, e.g. Application Support/Sandvox/Designs
	It's optional to be in the specified sub-directory.

	This is used for plugin bundles, but also for designs
	As of 1.5, the returned objects are KTAppPlugins, not NSBundles
*/
+ (NSDictionary *)pluginsWithExtension:(NSString *)extension sisterDirectory:(NSString *)dirPath
{
    NSMutableDictionary *buffer = [NSMutableDictionary dictionary];
    
	float appVersion = [[[NSBundle mainBundle] version] floatVersion];
    NSString *builtInPlugInsPath = [[NSBundle mainBundle] builtInPlugInsPath];
    
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
		[NSArray arrayWithObjects:[NSApplication applicationName], dirPath, nil]];
		
	// Add this sub-dir to each path, along with just the path without the subdir
	NSEnumerator *theEnum = [libraryPaths objectEnumerator];
	NSString *libraryPath;
	NSMutableArray *paths = [NSMutableArray array];
	
	while (nil != (libraryPath = [theEnum nextObject]) )
	{
		[paths addObject:[libraryPath stringByAppendingPathComponent:subDir]];
		[paths addObject:[libraryPath stringByAppendingPathComponent:[NSApplication applicationName]]];
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
        while (pluginName = [pluginsEnumerator nextObject])
		{
            NSString *pluginPath = [path stringByAppendingPathComponent:pluginName];
            if ( [[pluginPath pathExtension] isEqualToString:extension] )
			{
                KTAbstractHTMLPlugin *plugin = [KTAppPlugin pluginWithPath:pluginPath];
                if (plugin) 
				{
					NSString *identifier = [plugin identifier];
					if (nil == identifier)
					{
						identifier = pluginName;
					}
					
					// Only use an "override" if its version is >= the built-in version.
					// This way, we can update the version with the app, and it supercedes any
					// specially installed versions.
					KTAppPlugin *alreadyInstalledPlugin = [buffer objectForKey:identifier];
					if (nil != alreadyInstalledPlugin
						|| [[[plugin bundle] version] floatVersion] >= [[alreadyInstalledPlugin version] floatVersion])
					{
						if (nil == [plugin minimumAppVersion]
							|| [[plugin minimumAppVersion] floatVersion] <= appVersion)		// plugin's version must be less/equal than app version, not more!
						{
							[buffer setObject:plugin forKey:identifier];

							if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ShowSearchPaths"])
							{
								// ALWAYS show an override, regardless of preference, to help with support.  But don't do for DEBUG since it's just clutter to us!
								NSLog(@"Found %@ in %@/", pluginName, [path stringByAbbreviatingWithTildeInPath]);
							}
						}
						else
						{
							NSLog(@"Not loading %@, application version %@ is required",
								  [[[plugin bundle] bundlePath] stringByAbbreviatingWithTildeInPath], [plugin minimumAppVersion]);
						}
					}
                }
            }
        }
    }
    
    if ( 0 == [buffer count] )
	{
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ShowSearchPaths"])
		{
			// Show item #1 in the list which is going to be the ~/Libary/Application Support/Sandvox SANS "PlugIns" or "Designs"?
			NSLog(@"Searched for '.%@' plugins in %@/", extension, [[paths objectAtIndex:1] stringByAbbreviatingWithTildeInPath]);
		}
		return nil;
    }
    
    return [NSDictionary dictionaryWithDictionary:buffer];
}

#pragma mark File Management

// NOTE: For Leopard, we can use:  - (BOOL)createDirectoryAtPath:(NSString *)pathwithIntermediateDirectories:(BOOL)createIntermediatesattributes:(NSDictionary *)attributeserror:(NSError **)error

+ (BOOL)createPathIfNecessary:(NSString *)storeDirectory error:(NSError **)outError
{
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    BOOL success = NO;
    
    int i, c;
    NSArray *components = [storeDirectory pathComponents];
    NSString *current = @"";
    c = [components count];  
    for ( i = 0; i < c; i++ ) 
	{
        NSString *anIndex = [components objectAtIndex:i];
        NSString *next = [current stringByAppendingPathComponent:anIndex];
        current = next;
        if ( ![[NSFileManager defaultManager] fileExistsAtPath:next] ) 
		{
            success = [defaultManager createDirectoryAtPath:next attributes:nil];
            if ( !success ) 
			{
				NSString *errorDescription = [NSString stringWithFormat:NSLocalizedString(@"Unable to create directory at path (%@).",@"Error: Unable to create directory at path (%@)."), next];
				*outError = [NSError errorWithDomain:NSCocoaErrorDomain
												code:NSFileWriteUnknownError
								localizedDescription:errorDescription];
                return NO;
            }
        } 
    }
    
    return YES;
}

@end

