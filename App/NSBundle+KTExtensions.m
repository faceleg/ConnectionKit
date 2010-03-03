//
//  NSBundle+KTExtensions.m
//  KTComponents
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
//

#import "NSBundle+KTExtensions.h"

#import "Debug.h"
#import "NSImage+Karelia.h"
#import "NSApplication+Karelia.h"
#import "KSAppDelegate.h"

@implementation NSBundle ( KTExtensions )

/*	Designs can contain their own specialised fonts. This method loads any found fonts ready for application use.
 
	I've updated this to use the newer 10.5 method ATSFontActivateFromFileReference
 
	but the notes here said that if running 10.5, the bundle key ATSApplicationFontsPath should be used.
  
 */

#warning Maybe use ATSApplicationFontsPath bundle key

- (void)loadLocalFonts
{
	NSString *fontsFolder = [self resourcePath];
	if (fontsFolder)
	{
		NSURL *fontsURL = [NSURL fileURLWithPath:fontsFolder];
		if (fontsURL)
		{
			FSRef fsRef;
			(void)CFURLGetFSRef((CFURLRef)fontsURL, &fsRef);
			
			OSStatus error = ATSFontActivateFromFileReference(&fsRef, kATSFontContextLocal, kATSFontFormatUnspecified, 
													 NULL, kATSOptionFlagsProcessSubdirectories, NULL);

			if (noErr != error) NSLog(@"Error %s activating fonts in bundle %@", GetMacOSStatusErrorString(error), [[self bundlePath] lastPathComponent]);
		}
	}
}


#pragma mark -
#pragma mark HTML Template files

- (NSString *)entityName
{
	id result = [self objectForInfoDictionaryKey:@"KTMainEntityName"];
    return result;
}

- (NSString *)templateRSSAsString
{
	static NSMutableDictionary *sXMLTemplates = nil;
	if (nil == sXMLTemplates)
	{
		sXMLTemplates = [[NSMutableDictionary alloc] init];
	}
	
	NSString *result = [sXMLTemplates objectForKey:[self bundleIdentifier]];
	if ( [result isEqual:[NSNull null]] )
	{
		result = nil;
	}
	else if (nil == result)
	{
		NSString *templateName = @"RSSTemplate";
		NSString *path = [self overridingPathForResource:templateName ofType:@"xml"];
		if (nil != path)
		{
			NSData *data = [NSData dataWithContentsOfFile:path];
			result = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
		}
		if (nil != result)
		{
			[sXMLTemplates setObject:result forKey:[self bundleIdentifier]];
		}
		else
		{
			[sXMLTemplates setObject:[NSNull null] forKey:[self bundleIdentifier]];
		}

	}
	return result;
}


// NOTE: YOU PROBABLY WANT TO DISCOURAGE THIS FROM BEING CALLED MULTIPLE TIMES FOR THE SAME RESOURCE, SINCE IT MIGHT LOG A LOT!

- (NSString *)overridingPathForResource:(NSString *)name ofType:(NSString *)ext;
{
	NSString *path = [NSApplication applicationSupportPath];
	NSString *bundleDescription = nil;
	if (self == [NSBundle mainBundle])
	{
		bundleDescription = @"application";
	}
	else
	{
		bundleDescription = @"plugin";
	}

	if (self != [NSBundle mainBundle])
	{
		path = [path stringByAppendingPathComponent:[self bundleIdentifier]];
	}
	
	NSString *filePath = (nil == ext) ? name : [NSString stringWithFormat:@"%@.%@", name, ext];
	
	NSString *fullPath = [path stringByAppendingPathComponent:filePath];
	if ( ![[NSFileManager defaultManager] fileExistsAtPath:fullPath] )
	{
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ShowSearchPaths"])
		{
			NSLog(@"Searched for %@ (from %@) in %@/", filePath, bundleDescription, [path stringByAbbreviatingWithTildeInPath]);
		}
		fullPath = [self pathForResource:name ofType:ext];		// just default behavior since we didn't find override file
	}
	else	// file exists, log that we found it there ALWAYS
	{
		NSLog(@"Found %@ (from %@) in %@/", filePath, bundleDescription, [path stringByAbbreviatingWithTildeInPath]);
	}
	return fullPath;
}

- (NSString *)overridingPathForResource:(NSString *)name ofType:(NSString *)ext inDirectory:(NSString *)subpath
{
	// not implemented right now, just use standard
	NSString *fullPath = [self pathForResource:name ofType:ext inDirectory:subpath];
	return fullPath;
}


@end
