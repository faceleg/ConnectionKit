//
//  NSBundle+KTExtensions.m
//  KTComponents
//
//  Copyright (c) 2004-2005 Biophony, LLC. All rights reserved.
//

#import "NSBundle+KTExtensions.h"

#import "Debug.h"
#import "NSImage+KTExtensions.h"
#import "NSApplication+KTExtensions.h"
#import "KTAbstractPlugin.h"		// just for class reference for bundle


@implementation NSBundle ( KTExtensions )

+ (Class)principalClassForBundle:(NSBundle *)aBundle
{
    Class BundleClass = [aBundle principalClass];
    
    if ( Nil == BundleClass )
    {
        NSString *className = [aBundle objectForInfoDictionaryKey:@"NSPrincipalClass"];
        BundleClass = NSClassFromString(className);
    }
    
    return BundleClass;
}

# pragma mark -
# pragma mark Localized keys

// Get localized string, with fallback of the string itself.

- (NSString *)localizedStringForString:aString language:(NSString *)aLocalization
{
	return [self localizedStringForString:aString language:aLocalization fallback:aString];
}

// Get localized string, with given fallback string

- (NSString *)localizedStringForString:aString language:(NSString *)aLocalization fallback:(NSString *)aFallbackString
{
	NSString *result = nil;	// fallback
//	if ([aLocalization isEqualToString:@"en"]) aLocalization = @"English";
//	if ([aLocalization isEqualToString:@"fr"]) aLocalization = @"French";
	
	// First try to get a localization that we have given the language of the site.
	NSArray *locs = [NSBundle
	preferredLocalizationsFromArray:[self localizations]
					 forPreferences:[NSArray arrayWithObject:aLocalization]];
	
	if (![locs count])
	{
		// If we don't have that language, see if we can get the language that is the user's language
		locs = [NSBundle preferredLocalizationsFromArray:[self localizations] forPreferences:nil];
	}
	// If we don't have that, then we can't localize, just use the original English.
	
	if ([locs count])
	{
		NSString *path = [self pathForResource:@"Localizable" ofType:@"strings" inDirectory:nil forLocalization:[locs objectAtIndex:0]];
			
		if (nil != path)	// We should find this, but in case it's missing we'll just use original English.
		{
			NSDictionary *stringDict = [NSDictionary dictionaryWithContentsOfFile:path];
			NSString *translated = [stringDict objectForKey:aString];
			if (nil != translated)
			{
				result = translated;
			}
			else if ([[NSUserDefaults standardUserDefaults] boolForKey:@"NSShowNonLocalizedStrings"])
			{
				NSLog(@"Could not find '%@' in localization '%@' from bundle '%@'", aString, aLocalization, [self bundlePath]);
			}
			
		}
	}
	if (nil == result)
	{
		// LOG((@"Did not find entry for %@, using fallback of %@", aString, aFallbackString));
		result = aFallbackString;
	}
	return result;
}

- (NSString *)localizedObjectForInfoDictionaryKey:(NSString *)aKey
{
	NSString *result = [[self localizedInfoDictionary] objectForKey:aKey];
	if (nil == result)
	{
		result = [self objectForInfoDictionaryKey:aKey];
	}
	// old way: look it up more manually.  I think we can delete this.
//	NSString *result = [self localizedStringForKey:aKey value:aKey table:@"InfoPlist"];
//	if ([result isEqualToString:aKey])
//	{
//		LOG((@"NOT FINDING localizedStringForKey:%@ in %@", aKey, [[self bundlePath] lastPathComponent]));
//		result = [self objectForInfoDictionaryKey:aKey];
//		if (nil == result)
//		{
//			LOG((@"Not finding info dict object for key %@ in %@", aKey, [[self bundlePath] lastPathComponent]));
//		}
//	}
	return result;
}

- (NSString *)helpAnchor
{
	return [self objectForInfoDictionaryKey:@"KTHelpAnchor"];
}

# pragma mark -
# pragma mark Non-localized keys

- (NSString *)entityName
{
	id result = [self objectForInfoDictionaryKey:@"KTMainEntityName"];
    return result;
}

- (NSString *)version;				// specified as CFBundleShortVersionString
{
    id retVal = [self objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    return retVal;
}

- (NSString *)buildVersion;				// specified as CFBundleVersion
{
    id retVal = [self objectForInfoDictionaryKey:@"CFBundleVersion"];
    return retVal;
}

#pragma mark -
#pragma mark HTML Template files


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

/* This code from Robert Grant might be helpful in rewriting to not be deprecated

NSBundle* bundle = [NSBundle mainBundle];
// fonts folder points to standard or deluxe fonts depending on license type
NSString* fontsFolderString =  [bundle pathForResource: fontsFolder() ofType: nil];
FSRef fsRef;
FSSpec fsSpec;
int osstatus = FSPathMakeRef( (UInt8*)[fontsFolderString UTF8String], &fsRef, NULL);
if ( osstatus == noErr) {
	osstatus = FSGetCatalogInfo( &fsRef, kFSCatInfoNone, NULL, NULL, &fsSpec, NULL);
	ATSFontContainerRef container;
	osstatus = ATSFontActivateFromFileSpecification(&fsSpec, kATSFontContextLocal, kATSFontFormatUnspecified, NULL, kATSOptionFlagsProcessSubdirectories, &container);
}
*/

- (void)loadLocalFonts
{
	NSString *fontsFolder;
	if ((fontsFolder = [self resourcePath]))
	{
		NSURL *fontsURL;
		if ((fontsURL = [NSURL fileURLWithPath:fontsFolder]))
		{
			FSRef fsRef;
			FSSpec fsSpec;
			(void)CFURLGetFSRef((CFURLRef)fontsURL, &fsRef);
			if (FSGetCatalogInfo(&fsRef, kFSCatInfoNone, NULL, NULL, &fsSpec, NULL) == noErr)
			{
				(void) FMActivateFonts(&fsSpec, NULL, NULL, kFMLocalActivationContext);
			}
		}
	}
}

// NOTE: YOU PROBABLY WANT TO DISCOURAGE THIS FROM BEING CALLED MULTIPLE TIMES FOR THE SAME RESOURCE, SINCE IT MIGHT LOG A LOT!

- (NSString *)overridingPathForResource:(NSString *)name ofType:(NSString *)ext;
{
	NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *path = [[libraryPaths objectAtIndex:0] stringByAppendingPathComponent:[NSApplication applicationName]];
	NSBundle *ktComponentsBundle = [NSBundle bundleForClass:[KTAbstractPlugin class]];
	NSString *bundleDescription = nil;
	if (self == [NSBundle mainBundle])
	{
		bundleDescription = @"application";
	}
	else if (self == ktComponentsBundle)
	{
		bundleDescription = @"KTComponents";
	}
	else
	{
		bundleDescription = @"plugin";
	}

	if (self != [NSBundle mainBundle] && self != ktComponentsBundle)
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

#pragma mark -
#pragma mark Nib Loading

/*!	Instance method, not class method; should help us find nibs better.
*/
- (BOOL)loadNibNamed:(NSString *)nibName owner:(id)owner
{
    NSString *fileName = [self pathForResource:nibName ofType:@"nib"];
    NSDictionary *context = [NSDictionary dictionaryWithObject:owner forKey:@"NSOwner"];
    return [NSBundle loadNibFile:fileName externalNameTable:context withZone:[owner zone]];
}

/*	Convenience method that calls through to -loadNibFile:externalNameTable:withZone:
 */
- (BOOL)loadNibNamed:(NSString *)nibName owner:(id)owner topLevelObjects:(NSArray **)topLevelObjects
{
	NSMutableArray *mutableTopLevelObjects = [NSMutableArray array];
	
	NSDictionary *nameTable = [NSDictionary dictionaryWithObjectsAndKeys:
		owner, NSNibOwner,
		mutableTopLevelObjects, NSNibTopLevelObjects,
		nil];
	
	BOOL result = [self loadNibFile:nibName externalNameTable:nameTable withZone:[owner zone]];
	
	*topLevelObjects = [NSArray arrayWithArray:mutableTopLevelObjects];
	
	return result;
}

@end
