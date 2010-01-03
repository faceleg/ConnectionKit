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
 
	If we are *running* 10.4 then use the old-fashioned way.  But if we are running 10.5, the 
	bundle key ATSApplicationFontsPath should be used instead.
 
	We were having hellish keychain issues when using the 10.4 legacy method, and we need that since
	the new 10.5 method doesn't exist if you are targetting 10.4 or 10.5.
 
	This is NOT generic Karelia code (any more) and when we start targetting 10.5+ then we should
	get rid of this method altogether.
 
 */

#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4

#warning It is time to completel overhaul this to use the Leopard version, not do this hack.

#endif

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
			
			OSStatus error = -8675309;	// seed with a bogus error, in case we can't get it really filled

// 10.5 version if we weren't using ATSApplicationFontsPath
//				error = ATSFontActivateFromFileReference(&fsRef, kATSFontContextLocal, kATSFontFormatUnspecified, 
//													 NULL, kATSOptionFlagsProcessSubdirectories, NULL);

			FSSpec fsSpec;
			if (FSGetCatalogInfo(&fsRef, kFSCatInfoNone, NULL, NULL, &fsSpec, NULL) == noErr)
			{
				error = ATSFontActivateFromFileSpecification(&fsSpec,
															 kATSFontContextLocal,
															 kATSFontFormatUnspecified,
															 NULL,
															 kATSOptionFlagsProcessSubdirectories,
															 NULL);
			}
	
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
