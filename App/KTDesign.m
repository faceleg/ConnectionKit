//
//  KTDesign.m
//  Marvel
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
//



#import "KT.h"
#import "KTDesign.h"
#import "KTDesignFamily.h"
#import "KTImageScalingSettings.h"
#import "KTStringRenderer.h"

#import "NSApplication+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSBundle+KTExtensions.h"
#import "NSImage+Karelia.h"
#import "NSImage+KTExtensions.h"
#import "NSSet+Karelia.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"
#import "NSColor+Karelia.h"

#import "Debug.h"

const int kDesignThumbWidth = 100;
const int kDesignThumbHeight = 65;

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

+ (NSArray *)genreValues;
{
	NSArray *result = [NSArray arrayWithObjects:@"minimal", @"glossy", @"bold", @"artistic", @"specialty", nil ];
	return result;
}
+ (NSArray *)colorValues;
{
	NSArray *result = [NSArray arrayWithObjects:@"bright", @"dark", @"colorful", nil ];
	return result;
}
+ (NSArray *)widthValues;
{
	NSArray *result = [NSArray arrayWithObjects:@"standard", @"wide", @"flexible", nil ];
	return result;
}

+ (void)load
{
	[self registerPluginClass:[self class] forFileExtension:kKTDesignExtension];
}

- (void) loadLocalFontsIfNeeded;
{
	if (!myFontsLoaded
		&& [self hasLocalFonts] 
		&& (nil != [self imageReplacementTags])
		&& [[NSUserDefaults standardUserDefaults] boolForKey:@"LoadLocalFonts"])
	{
		[[self bundle] loadLocalFonts];			// load in the fonts (ON TIGER)
	}
	myFontsLoaded = YES;	// once this is called, no need to check or load again.
}

- (id)initWithBundle:(NSBundle *)bundle;
{
	if ((self = [super initWithBundle:bundle]) != nil)
	{
		;		// do not load local fonts;  we probably won't need them.
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
	
	NSMutableString *categoryProblems = [NSMutableString string];
	NSString *genre = [aCandidateBundle objectForInfoDictionaryKey:@"genre"];
	NSString *color = [aCandidateBundle objectForInfoDictionaryKey:@"color"];
	NSString *width = [aCandidateBundle objectForInfoDictionaryKey:@"width"];
	if (nil == genre || ![[KTDesign genreValues] containsObject:genre])
	{
		[categoryProblems appendFormat:@"genre = %@; must be %@", genre, [[KTDesign genreValues] description]];
	}
	if (nil == color || ![[KTDesign colorValues] containsObject:color])
	{
		if (![categoryProblems isEqualToString:@""]) [categoryProblems appendString:@"; "];
		[categoryProblems appendFormat:@"color = %@: must be %@", color, [[KTDesign colorValues] description]];
	}
	if (nil == width || ![[KTDesign widthValues] containsObject:width])
	{
		if (![categoryProblems isEqualToString:@""]) [categoryProblems appendString:@"; "];
		[categoryProblems appendFormat:@"width = %@: must be %@", width, [[KTDesign widthValues] description]];
	}
	if (![categoryProblems isEqualToString:@""])
	{
		DJW((@"TO NSLOG: In %@: %@", [aCandidateBundle bundlePath], categoryProblems));
		
		// Should be NSLog though...
	}
	
	return result;
}

// Go through a list of designs and 
+ (NSArray *)consolidateDesignsIntoFamilies:(NSArray *)designs
{
	NSMutableArray *result = [NSMutableArray array];
	NSMutableDictionary *families = [NSMutableDictionary dictionary];	// remember what we've seen
	for (KTDesign *design in designs)
	{
		NSString *parentBundleIdentifier = nil;
		if (nil != (parentBundleIdentifier = [design parentBundleIdentifier]))
		{
			KTDesignFamily *family = [families objectForKey:parentBundleIdentifier];
			if (!family)
			{
				family = [[[KTDesignFamily alloc] init] autorelease];
				[families setObject:family forKey:parentBundleIdentifier];	// so we can find later
				[result addObject:family];	// first time seen, so add to result list
			}
			[family addDesign:design];	// add to list of children
		}
		else
		{
			[result addObject:design];
		}
	}
	return [NSArray arrayWithArray:result];
}

#pragma mark -
#pragma mark Init & Dealloc

- (void)dealloc
{
    [myThumbnail release];
	CGImageRelease(myThumbnailCG);  // CGImageRelease handles the ref being nil, unlike CFRelease
	[myResourceFileURLs release];
	
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

- (NSString *)contributor
{
	return [[self bundle] objectForInfoDictionaryKey:@"contributor"];
}

- (NSString *)genre
{
	return [[self bundle] objectForInfoDictionaryKey:@"genre"];
}
- (NSString *)color	// dark, light, or colorful
{
	return [[self bundle] objectForInfoDictionaryKey:@"color"];
}
- (NSString *)width;	// standard, wide, or flexible
{
	return [[self bundle] objectForInfoDictionaryKey:@"width"];
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
	if (nil == urlString)
	{
		urlString = [[self bundle] objectForInfoDictionaryKey:@"URL"];
	}

	return (nil != urlString) ? [KSURLFormatter URLFromString:urlString] : nil;
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

#pragma mark Image Replacement

- (NSDictionary *)imageReplacementTags
{
	return [[self bundle] objectForInfoDictionaryKey:@"imageReplacement"];
}

- (NSImage *)replacementImageForCode:(NSString *)aCode string:(NSString *)aString size:(NSNumber *)aSize
{
	[self loadLocalFontsIfNeeded];		// just make sure they are loaded here

	NSImage *result = nil;
	NSDictionary *replacementParams = [[self imageReplacementTags] objectForKey:aCode];
	if (nil != replacementParams)
	{
		NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:replacementParams];
        
        NSURL *compositionURL = [self URLForCompositionForImageReplacementCode:aCode];
		if (compositionURL)
		{
			OFF((@"IR>>>> Using QC file: %@", compositionURL));
			
            [params setObject:aString forKey:@"String"];		// put in mandatory string input
			[params setValue:aSize forKey:@"Size"];			// put in optional size input
            [params removeObjectForKey:@"qtzFile"];				// don't want to send this param
            
			result = [[KTStringRenderer rendererWithFile:[compositionURL path]]
                      imageWithInputs:params];
		}
	}
	return result;
}

- (NSURL *)URLForCompositionForImageReplacementCode:(NSString *)code;
{
    NSDictionary *params = [[self imageReplacementTags] objectForKey:code];
    
	NSString *fileName = [params objectForKey:@"qtzFile"];
    if (!fileName) fileName = code;
    
    NSString *path = [[self bundle] pathForResource:fileName ofType:@"qtz"];
    if (path)
    {
        return [NSURL fileURLWithPath:path];
    }
    
    return nil;
}

#pragma mark -

- (NSImage *)thumbnail
{
	if (nil == myThumbnail)
	{
		NSString *path = [[self bundle] pathForImageResource:@"thumbnail"];
		if (nil != path)
		{
			NSImage *unscaledThumb = [[[NSImage alloc] initByReferencingFile:path] autorelease];
			[unscaledThumb normalizeSize];
			myThumbnail = [[unscaledThumb imageWithMaxWidth:kDesignThumbWidth height:kDesignThumbHeight] retain];
			// make sure thumbnail is not too big!
		}
	}
	return myThumbnail;
}

- (CGImageRef)thumbnailCG
{
	if (nil == myThumbnailCG)
	{
		NSString *path = [[self bundle] pathForImageResource:@"thumbnail"];
		if (nil != path)
		{
			CGImageSourceRef source = CGImageSourceCreateWithURL((CFURLRef)[NSURL fileURLWithPath:path],nil);
			if (source)
			{
				myThumbnailCG = CGImageSourceCreateImageAtIndex(source, 0, nil);
				CFRelease(source);
			}
		}
	}
	return myThumbnailCG;
}


+ (NSSet *)keyPathsForValuesAffectingThumbnailGloss
{
    return [NSSet setWithObject:@"thumbnail"];
}


// Special version that compares the titles - but uses the ParentName if it exists
- (NSComparisonResult)compareTitles:(KTDesign *)aDesign;
{
	return [[self titleOrParentName] caseInsensitiveCompare:[aDesign titleOrParentName]];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ %@", [super description], [[self bundle] bundleIdentifier]];
}

#pragma mark design coalescing into families

- (NSColor *)mainColor
{
	NSColor *result = nil;
	
	NSString *hexColorString = [[self bundle] objectForInfoDictionaryKey:@"MainColor"];
	if (hexColorString)
	{
		result = [NSColor colorFromHexRGB:hexColorString];
	}
	return result;
}

- (int)hierMenuType;
{
	NSNumber *hierMenuTypeNumber = [[self bundle] objectForInfoDictionaryKey:@"HierMenuType"];
	if (hierMenuTypeNumber)
	{
		return [hierMenuTypeNumber intValue];
	}
	return HIER_MENU_HORIZONTAL;		// default if not specified.  We may want to do HIER_MENU_NONE once designs are set up
}

- (BOOL)isFamilyPrototype
{
	BOOL result = NO;
	
	NSNumber *value = [[self bundle] objectForInfoDictionaryKey:@"IsFamilyPrototype"];
	if (value)
	{
		result = [value boolValue];
	}
	return result;
}

- (NSString *)parentName
{
	return [[self bundle] objectForInfoDictionaryKey:@"ParentName"];
}

- (NSString *)titleOrParentName
{
	NSString *result = [[self bundle] objectForInfoDictionaryKey:@"ParentName"];
	if (!result)
	{
		result = [self title];
	}
	return result;
}

- (NSString *)parentBundleIdentifier
{
	return [[self bundle] objectForInfoDictionaryKey:@"ParentBundleIdentifier"];
}

#pragma mark -
#pragma mark Publishing

/*!	Generate a path based on the identifier.  Remove white space, and append version string.
	so Foo Bar Baz will look like FooBarBaz.1
*/
+ (NSString *)remotePathForDesignWithIdentifier:(NSString *)identifier
{
    NSString *result = [identifier stringByRemovingWhiteSpace];
	result = [result stringByReplacing:@"." with:@"_"];		// some ISPs don't like "."
	return result;
}

/*  Convenience method to get the remote path of a design
 */
- (NSString *)remotePath
{
	NSString *result = [[self class] remotePathForDesignWithIdentifier:[[self bundle] bundleIdentifier]];
	return result;
}

#pragma mark -
#pragma mark Banner

- (BOOL)allowsBannerSubstitution
{
	NSString *bannerCSSSelector = [self bannerCSSSelector];
	BOOL result = (bannerCSSSelector && ![bannerCSSSelector isEqualToString:@""]);
	return result;
}

- (BOOL)hasLocalFonts
{
	BOOL result = [[[self bundle] objectForInfoDictionaryKey:@"hasLocalFonts"] boolValue];
	return result;
}

- (NSString *)bannerCSSSelector
{
	NSString *result = [[self bundle] objectForInfoDictionaryKey:@"bannerCSSSelector"];
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

/*	The width of the design for the iPhone's benefit.
 *	If no value is found in the dictionary we assume 771 pixels.
 */
- (unsigned)viewport
{
	unsigned result = 771;
	
	NSNumber *viewport = [[self bundle] objectForInfoDictionaryKey:@"viewport"];
	if (viewport) {
		unsigned probablyResult = [viewport unsignedIntValue];
		if (probablyResult > 100)
		{
			result = probablyResult;
		}
	}
	
	return result;
}

#pragma mark -
#pragma mark Resource data

/*	The URLs of all resource files that are to be uploaded when publishing the design
 */
- (NSSet *)resourceFileURLs
{
	if (!myResourceFileURLs)
	{
		NSMutableSet *buffer = [[NSMutableSet alloc] init];
		NSArray *extraIgnoredFiles = [[[self bundle] infoDictionary] objectForKey:@"KTIgnoredResources"];
		
		// Run through all files in the bundle
		NSString *designBundlePath = [[self bundle] bundlePath];
		NSEnumerator *resourcesEnumerator = [[[NSFileManager defaultManager] directoryContentsAtPath:designBundlePath] objectEnumerator];
		NSString *aFilename;
		
		while (aFilename = [resourcesEnumerator nextObject])
		{
			// Ignore any special files
			if ([aFilename isEqualToStringCaseInsensitive:@"Info.plist"] ||
				[[aFilename stringByDeletingPathExtension] isEqualToString:@"thumbnail"] ||
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
            NSString *resourceFilePath = [designBundlePath stringByAppendingPathComponent:aFilename];
			NSURL *resourceFileURL = [NSURL fileURLWithPath:resourceFilePath];
			NSString *UTI = [NSString UTIForFileAtPath:resourceFilePath];
			if ([UTI conformsToUTI:(NSString *)kUTTypeImage] ||
				[UTI conformsToUTI:(NSString *)kUTTypePlainText] ||
				[UTI conformsToUTI:(NSString *)kUTTypeRTF] ||
                [UTI isEqualToUTI:(NSString *)kUTTypeFolder])
			{
				OBASSERT(resourceFileURL);
                [buffer addObject:resourceFileURL];
			}
		}
		
		
		// Ignore the thumbnail
		[buffer removeObjectIgnoringNil:[[self bundle] pathForImageResource:@"thumbnail"]];
		
		
		// Tidy up
		myResourceFileURLs = [buffer copy];
		[buffer release];
	}
	
	return myResourceFileURLs;
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

#pragma mark -
#pragma mark IKImageBrowserViewItem

- (NSString *)  imageUID;  /* required */
{
	return [[self bundle] bundlePath];
}

/*! 
 @method imageRepresentationType
 @abstract Returns the representation of the image to display (required).
 @discussion Keys for imageRepresentationType are defined below.
 */
- (NSString *) imageRepresentationType; /* required */
{
	return IKImageBrowserCGImageRepresentationType;
}
/*! 
 @method imageRepresentation
 @abstract Returns the image to display (required). Can return nil if the item has no image to display.
 @discussion This methods is called frequently, so the receiver should cache the returned instance.
 */
- (id) imageRepresentation; /* required */
{
	return (id) [self thumbnailCG];
}
/*! 
 @method imageVersion
 @abstract Returns a version of this item. The receiver can return a new version to let the image browser knows that it shouldn't use its cache for this item
 */
- (NSUInteger) imageVersion;
{
	return 1;
}
/*! 
 @method imageTitle
 @abstract Returns the title to display as a NSString. Use setValue:forKey: with IKImageBrowserCellTitleAttribute to set text attributes.
 */
- (NSString *) imageTitle;
{
	return self.title;
}
/*! 
 @method imageSubtitle
 @abstract Returns the subtitle to display as a NSString. Use setValue:forKey: with IKImageBrowserCellSubtitleAttribute to set text attributes.
 */
- (NSString *) imageSubtitle;
{
	return self.contributor;
}
- (BOOL) isSelectable;
{
	return YES;
}

@end

