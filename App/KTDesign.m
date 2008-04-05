//
//  KTDesign.m
//  Marvel
//
//  Copyright (c) 2004-2005 Biophony, LLC. All rights reserved.
//



#import "KT.h"
#import "KTDesign.h"
#import "KTImageScalingSettings.h"
#import "KTStringRenderer.h"
#import "NSApplication+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSImage+KTExtensions.h"
#import "NSString+Karelia.h"
#import "NSString-Utilities.h"
#import "Debug.h"

@implementation KTDesign

#pragma mark -
#pragma mark Class Methods

+ (NSString *)pluginSubfolder
{
	return @"Designs";	// subfolder in App Support/APPNAME where this kind of plugin MAY reside.
}

+ (NSString *)applicationPluginPath	// Designs in their own top-level plugin dir
{
	NSString *genericPluginsPath = [super applicationPluginPath];
	NSString *result = [[genericPluginsPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Designs"];
	return result;
}



+ (void)load
{
	[self registerPluginClass:[self class] forFileExtension:kKTDesignExtension];
}

- (id)initWithBundle:(NSBundle *)bundle;
{
	if ((self = [super initWithBundle:bundle]) != nil) {
		[bundle loadLocalFonts];			// load in the fonts
	}
	return self;
}

+ (BOOL) validateBundle:(NSBundle *)aCandidateBundle;
{
	NSString *path = [aCandidateBundle pathForResource:@"main" ofType:@"css"];
	BOOL result = (nil != path);
	if (!result)
	{
		NSLog(@"Couldn't find main.css for %@, not enabling design", [aCandidateBundle bundlePath]);
	}
	return result;
}

#pragma mark -
#pragma mark Init & Dealloc

- (void)dealloc
{
    [myThumbnail release];
	[myResourceFiles release];
	
    [super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (int)numberOfSubDesigns;
{
	return 0;
}

- (NSArray *)subDesigns
{
	return nil;
}

/*!	Generate a path to this design.  Remove white space, and append version string.
	so Foo Bar Baz will look like FooBarBaz.1
*/
- (NSString *)remotePath;
{
	NSString *result = [[self identifier] removeWhiteSpace];
	NSString *version = [self version];
	if ((version != nil) 
		&& ![version isEqualToString:@""] 
		&& ![version isEqualToString:@"APP_VERSION"] 
		&& ([version floatVersion] > 1.0))
	{
		result = [result stringByAppendingFormat:@".%@", version];
	}
	result = [result stringByReplacing:@"." with:@"_"];		// some ISPs don't like "."
	return result;
}

- (NSString *)contributor
{
	return [[self bundle] objectForInfoDictionaryKey:@"contributor"];
}

- (NSString *)sidebarBorderable
{
	return [[self bundle] objectForInfoDictionaryKey:@"SidebarBorderable"];
}

- (NSString *)calloutBorderable
{
	return [[self bundle] objectForInfoDictionaryKey:@"CalloutBorderable"];
}

- (BOOL)menusUseNonBreakingSpaces
{
	BOOL result = YES;
	
	NSNumber *value = [[self bundle] objectForInfoDictionaryKey:@"KTMenusUseNonBreakingSpaces"];
	if (value)
	{
		result = [value boolValue];
	}
	
	return result;
}

- (NSURL *)URL		// the URL where this design comes from
{
	NSString *urlString = [[self bundle] objectForInfoDictionaryKey:@"url"];
	return (nil != urlString) ? [NSURL URLWithString:[urlString encodeLegally]] : nil;
}

/*!	Return path for placeholder image, if it exists
*/
- (NSString *)placeholderImagePath;
{
	return [[self bundle] pathForImageResource:@"placeholder"];
}

- (int)textWidth
{
	NSString *textWidthString = [[self bundle] objectForInfoDictionaryKey:@"textWidth"];
	int result = [textWidthString intValue];
	if (0 == result)
	{
		result = 320;		// give it a reasonable minimum default value
	}
	return result;
}

- (NSDictionary *)imageReplacementTags
{
	return [[self bundle] objectForInfoDictionaryKey:@"imageReplacement"];
}



- (NSImage *)replacementImageForCode:(NSString *)aCode string:(NSString *)aString size:(NSNumber *)aSize
{
	NSImage *result = nil;
	NSDictionary *replacementParams = [[self imageReplacementTags] objectForKey:aCode];
	if (nil != replacementParams)
	{
		NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:replacementParams];
		NSString *fileName = [params objectForKey:@"qtzFile"];
		if (nil == fileName)
		{
			fileName = aCode;
		}
		fileName = [[self bundle] pathForResource:fileName ofType:@"qtz"];
		if (nil != fileName)
		{
			DJW((@"IR>>>> Using QC file: %@", fileName));
			[params setObject:aString forKey:@"String"];		// put in mandatory string input
			
			if (nil != aSize)
			{
				[params setObject:aSize forKey:@"Size"];			// put in optional size input
			}
			[params removeObjectForKey:@"qtzFile"];				// don't want to send this param
			result = [[KTStringRenderer rendererWithFile:fileName] imageWithInputs:params];
		}
	}
	return result;
}

- (NSImage *)thumbnail
{
	if (nil == myThumbnail)
	{
		NSString *path = [[self bundle] pathForImageResource:@"thumbnail"];
		if (nil != path)
		{
			NSImage *unscaledThumb = [[[NSImage alloc] initByReferencingFile:path] autorelease];
			[unscaledThumb normalizeSize];
			myThumbnail = [[unscaledThumb imageWithMaxWidth:100 height:65] retain];
			// make sure thumbnail is not too big!
		}
	}
	return myThumbnail;
}

- (NSComparisonResult)compareTitles:(KTDesign *)aDesign;
{
	return [[self title] caseInsensitiveCompare:[aDesign title]];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ %@", [super description], [[self bundle] bundleIdentifier]];
}

- (BOOL)allowsBannerSubstitution
{
	NSString *bannerName = [self bannerName];
	BOOL result = ( (nil != bannerName) && ([bannerName length] > 0) );
	return result;
}

- (NSString *)bannerName
{
	NSDictionary *info = [[self bundle] infoDictionary];
	NSString *result = [info valueForKey:@"bannerName"];
	return result;
}

- (NSSize)bannerSize
{
	NSDictionary *info = [[self bundle] infoDictionary];
	int width = [[info valueForKey:@"bannerWidth"] intValue];
	int height = [[info valueForKey:@"bannerHeight"] intValue];
	if (!width) width = 800;
	if (!height) height = 200;
	return NSMakeSize(width, height);
}

/*	This is used by plugins (e.g. Photo and Movie) to determine what size they should fit their media into.
 *	Default values are taken from KTCachedImageTypes.plist but this allows designs to override them.
 */
- (KTImageScalingSettings *)imageScalingSettingsForUse:(NSString *)mediaUse
{
	KTImageScalingSettings *result = nil;
	
	// Pull the values out of the design bundle. They may well be nil
	NSDictionary *allMediaInfo = [[[self bundle] infoDictionary] objectForKey:@"KTScaledImageTypes"];
	NSDictionary *mediaInfo = [allMediaInfo objectForKey:mediaUse];
	if (!mediaInfo)
	{
		mediaInfo = [[self class] infoForMediaUse:mediaUse];
	}
	
	result = [KTImageScalingSettings scalingSettingsWithDictionaryRepresentation:mediaInfo];
	return result;
} 

- (NSSize)maximumMediaSizeForUse:(NSString *)mediaUse
{
	// Pull the values out of the design bundle. They may well be nil
	NSDictionary *allMediaInfo = [[[self bundle] infoDictionary] objectForKey:@"KTScaledImageTypes"];
	NSDictionary *mediaInfo = [allMediaInfo objectForKey:mediaUse];
	
	NSNumber *maxWidth = [mediaInfo objectForKey:@"maxWidth"];
	NSNumber *maxHeight = [mediaInfo objectForKey:@"maxHeight"];
	
	// Replace nil values with the default
	if (!maxWidth)
	{
		maxWidth = [[KTDesign infoForMediaUse:mediaUse] objectForKey:@"maxWidth"];
	}
	
	if (!maxHeight)
	{
		maxHeight = [[KTDesign infoForMediaUse:mediaUse] objectForKey:@"maxHeight"];
	}
	
	NSSize result = NSMakeSize([maxWidth unsignedIntValue], [maxHeight unsignedIntValue]);
	return result;
}

/*	The width of the design for the iPhone's benefit.
 *	If no value is found in the dictionary we assume 771 pixels.
 */
- (unsigned)viewport
{
	unsigned result = 771;
	
	NSNumber *viewport = [[self bundle] objectForInfoDictionaryKey:@"viewport"];
	if (viewport) {
		result = [viewport unsignedIntValue];
	}
	
	return result;
}

#pragma mark -
#pragma mark Resource data

/*	The full paths of all resource files that are to be uploaded when publishing the design
 */
- (NSSet *)resourceFiles
{
	if (!myResourceFiles)
	{
		NSMutableSet *resourceFiles = [[NSMutableSet alloc] init];
		NSArray *extraIgnoredFiles = [[[self bundle] infoDictionary] objectForKey:@"KTIgnoredResources"];
		
		// Run through all files in the bundle
		NSString *myPath = [[self bundle] bundlePath];
		NSEnumerator *resourcesEnumerator = [[[NSFileManager defaultManager] directoryContentsAtPath:myPath] objectEnumerator];
		NSString *aFilename;
		
		while (aFilename = [resourcesEnumerator nextObject])
		{
			// Ignore any special files
			if ([aFilename isEqualToStringCaseInsensitive:@"Info.plist"] ||
				[aFilename isEqualToString:@"thumbnail.png"] ||
				[aFilename hasPrefix:@"."]) {
				continue;
			}
			
			if (extraIgnoredFiles)
			{
				 if ([extraIgnoredFiles containsObject:aFilename]) {
					continue;
				}
			}
			else
			{
				if ([[aFilename stringByDeletingPathExtension] isEqualToString:@"placeholder"]) {
					continue;
				}
			}
			
			
			// Locate the full path and add to the list if of a suitable type
			NSString *filePath = [myPath stringByAppendingPathComponent:aFilename];
			NSString *UTI = [NSString UTIForFileAtPath:filePath];
			if ([NSString UTI:UTI conformsToUTI:(NSString *)kUTTypeImage] ||
				[NSString UTI:UTI conformsToUTI:(NSString *)kUTTypePlainText] ||
				[NSString UTI:UTI conformsToUTI:(NSString *)kUTTypeRTF])
			{
				[resourceFiles addObject:filePath];
			}
		}
		
		
		// Tidy up
		myResourceFiles = [resourceFiles copy];
		[resourceFiles release];
	}
	
	return myResourceFiles;
}

/*	Returns the full data of the specified resource.
 *	If requested can also get the resource's MIME Type.
 */
- (NSData *)dataForResourceAtPath:(NSString *)path MIMEType:(NSString **)mimeType error:(NSError **)error
{
	NSString *basePath = [[self bundle] resourcePath];
	NSString *fullPath = [basePath stringByAppendingPathComponent:path];
	
	NSData *result = [NSData dataWithContentsOfFile:fullPath options:0 error:error];
	
	if (result && mimeType)
	{
		*mimeType = [NSString MIMETypeForUTI:[NSString UTIForFileAtPath:fullPath]];
	}
	
	return result;
}

/*	Every design should have a main.css file; this is a shortcut to get its data
 */
- (NSData *)mainCSSData
{
	NSError *error = nil;
	NSData *result = [self dataForResourceAtPath:@"main.css" MIMEType:NULL error:&error];
	
	if (!result)
	{
		NSLog(@"Couldn't find main.css in bundle %@. Error: %@", [self identifier], error);
	}
	
	return result;
}

@end

