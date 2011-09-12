//
//  KTDesign.m
//  Marvel
//
//  Copyright 2004-2011 Karelia Software. All rights reserved.
//



#import "KT.h"
#import "KTDesign.h"
#import "KTDesignFamily.h"
#import "KTImageScalingSettings.h"
#import "KTStringRenderer.h"

#import "KTDesignFamily.h"
#import "SVHTMLContext.h"

#import "NSApplication+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSBundle+KTExtensions.h"
#import "NSImage+Karelia.h"
#import "NSImage+KTExtensions.h"
#import "NSSet+Karelia.h"
#import "NSString+Karelia.h"
#import "NSArray+Karelia.h"
#import "NSColor+Karelia.h"

#import "KSURLFormatter.h"

#import "Debug.h"

const int kDesignThumbWidth = 100;
const int kDesignThumbHeight = 65;

@implementation KTDesign

@synthesize thumbnail = _thumbnail;
@synthesize thumbnailCG = _thumbnailCG;
@synthesize resourceFileURLs = _resourceFileURLs;
@synthesize familyPrototype = _familyPrototype;
@synthesize family = _family;
@synthesize thumbnails = _thumbnails;
@synthesize fontsLoaded = _fontsLoaded;
@synthesize contracted = _contracted;
@synthesize imageVersion = _imageVersion;
@synthesize variationIndex = _variationIndex;


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
	NSArray *result = [NSArray arrayWithObjects:@"minimal", @"basic", @"glossy", @"bold", @"artistic", @"specialty", nil ];
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

+ (BOOL) validateBundle:(NSBundle *)aCandidateBundle;
{
	NSString *path = [aCandidateBundle pathForResource:@"main" ofType:@"css"];
	BOOL result = (nil != path);
	if (!result)
	{
		NSLog(@"Couldn't find main.css for %@, not enabling design", [aCandidateBundle bundlePath]);
	}
	
	// Point out problems in categorization. This will be useful for third-party designers to clean up their act :-)
	
	NSMutableString *categoryProblems = [NSMutableString string];
	NSString *genre = [aCandidateBundle objectForInfoDictionaryKey:@"genre"];
	NSString *color = [aCandidateBundle objectForInfoDictionaryKey:@"color"];
	NSString *width = [aCandidateBundle objectForInfoDictionaryKey:@"width"];
	if (nil == genre || ![[KTDesign genreValues] containsObject:genre])
	{
		[categoryProblems appendFormat:@"genre = %@; must be %@", genre, [[[KTDesign genreValues] description] condenseWhiteSpace]];
	}
	if (nil == color || ![[KTDesign colorValues] containsObject:color])
	{
		if (![categoryProblems isEqualToString:@""]) [categoryProblems appendString:@"; "];
		[categoryProblems appendFormat:@"color = %@: must be %@", color, [[[KTDesign colorValues] description] condenseWhiteSpace]];
	}
	if (nil != width && ![[KTDesign widthValues] containsObject:width])		// Only log if unrecognized value; nil is OK
	{
		if (![categoryProblems isEqualToString:@""]) [categoryProblems appendString:@"; "];
		[categoryProblems appendFormat:@"width = %@: must be %@", width, [[[KTDesign widthValues] description] condenseWhiteSpace]];
	}
	NSString *identifier = [aCandidateBundle bundleIdentifier];
#pragma unused (identifier)
	if (![categoryProblems isEqualToString:@""]
#ifdef DEBUG
		&& [identifier hasPrefix:@"sandvox."]	// Don't bother logging 3rd-party issues for debug builds.
#endif
		)	
	{
		DJW((@"In %@: %@", identifier, categoryProblems));
	}
	
	return result;
}

// Go through a list of designs and reorganize as a tree.
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


// Go through a list of designs and reorganize as a tree.
+ (NSArray *)reorganizeDesigns:(NSArray *)designs familyRanges:(NSArray **)outRanges
{
	int index = 0;
	NSArray *designsAndFamilies = [[self class] consolidateDesignsIntoFamilies:designs];	// now we have a nice ordering.
	NSMutableArray *result = [NSMutableArray array];
	NSMutableArray *ranges = [NSMutableArray array];
	for (id designOrFamily in designsAndFamilies)
	{
		if ([designOrFamily isKindOfClass:[KTDesignFamily class]])
		{
			// Add all of the subdesigns, and add a new range to my list of groups.

			KTDesignFamily *family = (KTDesignFamily *)designOrFamily;
			NSArray *subDesigns = [[family designs] allObjects];
			KTDesign *familyPrototype = [family familyPrototype];
			familyPrototype.family = family;		// put reference to family (which has weak references to other designs) in first design in group so we can scrub
			
			if ([subDesigns count] > 1)
			{
				NSRange newRange = NSMakeRange(index,[subDesigns count]);
				// Ignore one-design families; not really a group.
				[ranges addObject:[NSValue valueWithRange:newRange]];
			}
			[result addObjectsFromArray:subDesigns];
			index += [subDesigns count];
		}
		else
		{
			[result addObject:designOrFamily];	// just add this design
			index++;
		}
	}
	if (outRanges)
	{
		*outRanges = [NSArray arrayWithArray:ranges];
	}
	return [NSArray arrayWithArray:result];
}

#pragma mark -
#pragma mark Init & Dealloc

- (void) loadLocalFontsIfNeeded;
{
	if (!_fontsLoaded
		&& [self hasLocalFonts] 
		&& (nil != [self imageReplacementTags])
		&& [[NSUserDefaults standardUserDefaults] boolForKey:@"LoadLocalFonts"])
	{
		[[self bundle] loadLocalFonts];			// load in the fonts (ON TIGER)
	}
	_fontsLoaded = YES;	// once this is called, no need to check or load again.
}

- (id)initWithBundle:(NSBundle *)bundle variation:(NSUInteger)variationIndex;
{
	_variationIndex = variationIndex;
	_imageVersion = NSNotFound;		// NSNotFound means not scrubbed yet, so use generic "parent" title
    
	if ((self = [super initWithBundle:bundle variation:variationIndex]) != nil)
	{
        ;		// do not load local fonts;  we probably won't need them.
		self.thumbnails = [NSMutableDictionary dictionary];
	}
	return self;
}

- (void)dealloc
{
 	CGImageRelease(_thumbnailCG);  // CGImageRelease handles the ref being nil, unlike CFRelease
	_thumbnailCG = nil;

    self.thumbnail = nil;
    self.resourceFileURLs = nil;
    self.familyPrototype = nil;
    self.family = nil;
    self.thumbnails = nil;
	
    [super dealloc];
}

#pragma mark -
#pragma mark Imports

- (NSArray *)imports;
{
	NSArray *result = [[[self bundle] infoDictionary] objectForKey:@"import"];
	return result;
}

- (NSDictionary *)conditionalCommentsForIE;
{
	NSDictionary *result = [[[self bundle] infoDictionary] objectForKey:@"IE"];
	return result;
}

#pragma mark -
#pragma mark Variations

- (NSDictionary *)variationDict		// nil if no variation
{
	NSDictionary *result = nil;
	if (NSNotFound != _variationIndex)
	{
		NSArray *variations = [[[self bundle] infoDictionary] objectForKey:@"variations"];
		if (_variationIndex < [variations count])
		{
			result = [variations objectAtIndex:_variationIndex];
		}
	}
	return result;
}

// Handle variations

- (id)pluginPropertyForKey:(NSString *)key
{
	NSDictionary *variationDict = [self variationDict];
	if (variationDict)
	{
		id result = [variationDict objectForKey:key];
		if (result)
		{
			return result;
		}
	}
	return [super pluginPropertyForKey:key];
}

// Backward compatibility for obsolete keys.  Check the regular key first, but then try obsolete version.

- (id)pluginPropertyForKey:(NSString *)key obsoleteKey:(NSString *)key2
{
	NSString *result = [self pluginPropertyForKey:key];
	if (!result)
	{
		result = [self pluginPropertyForKey:key2];
	}
	return result;
}



- (NSString *)title;
{
	NSDictionary *variationDict = [self variationDict];
	if (variationDict)
	{
		NSString *suffix = [variationDict objectForKey:@"suffix"];
		if (suffix)
		{
			return [NSString stringWithFormat:@"%@ %@", [super title], suffix];
		}
	}
	return [super title];	
}

// For a variation, append the filename to the CFBundleIdentifier
- (NSString *)identifier;
{
	if (!self.isFamilyPrototype)		// don't mess with identifier if it's the family prototype.
	{
		NSDictionary *variationDict = [self variationDict];
		if (variationDict)
		{
			NSString *file = [variationDict objectForKey:@"file"];
			if (file)
			{
				return [NSString stringWithFormat:@"%@.%@", [super identifier], file];
			}
			else
			{
				NSLog(@"Cannot find 'file' key for variation %d in %@", _variationIndex, self);
			}
		}
	}
	return [super identifier];	
}

- (NSString *)thumbnailPath
{
	NSString *thumbnailName = @"thumbnail";
	NSDictionary *variationDict = [self variationDict];
	if (variationDict)
	{
		NSString *file = [variationDict objectForKey:@"file"];
		if (file)
		{
			thumbnailName = [NSString stringWithFormat:@"%@.%@", file, thumbnailName];	// e.g. orange.thumbnail.tiff
		}
	}
	NSString *path = [[self bundle] pathForImageResource:thumbnailName];
	return path;
}

- (NSString *)parentTitle
{
	if (NSNotFound != _variationIndex)
	{
		return [super title];
	}
	return [self pluginPropertyForKey:@"parentTitle" obsoleteKey:@"ParentTitle"];

}

- (NSString *)parentBundleIdentifier
{
	if (NSNotFound != _variationIndex)
	{
		return [super identifier];
	}
	return [self pluginPropertyForKey:@"parentBundleIdentifier" obsoleteKey:@"ParentBundleIdentifier"];
}



#pragma mark -
#pragma mark Accessors

- (NSString *)contributor
{
	return [self pluginPropertyForKey:@"contributor"];
}

- (NSString *)genre		// REQUIRED ... see genreValues
{
	NSString *result = [self pluginPropertyForKey:@"genre"];
	if (![[KTDesign genreValues] containsObject:result])
	{
		result = nil;
	}
	return result;
}
- (NSString *)color		// REQUIRED ... see colorValues
{
	NSString *result = [self pluginPropertyForKey:@"color"];
	if (![[KTDesign colorValues] containsObject:result])
	{
		result = nil;
	}
	return result;
}
- (NSString *)width;	// standard [default], wide, or flexible
{
	NSString *result = [self pluginPropertyForKey:@"width"];
	if (!result || ![[KTDesign widthValues] containsObject:result])
	{
		result = @"standard";	// default to standard if not specified.
	}
	return result;
}


- (NSString *)sidebarBorderable
{
	return [self pluginPropertyForKey:@"sidebarBorderable" obsoleteKey:@"SidebarBorderable"];
}

- (NSString *)calloutBorderable
{
	return [self pluginPropertyForKey:@"calloutBorderable" obsoleteKey:@"CalloutBorderable"];
}

- (BOOL)menusUseNonBreakingSpaces
{
	BOOL result = NO;
	
	NSNumber *value = [self pluginPropertyForKey:@"menusUseNonBreakingSpaces" obsoleteKey:@"KTMenusUseNonBreakingSpaces"];
	if (value)
	{
		result = [value boolValue];
	}
	
	return result;
}

- (NSURL *)URL		// the URL where this design comes from
{
	NSString *urlString = [self pluginPropertyForKey:@"url" obsoleteKey:@"URL"];

	return (nil != urlString) ? [KSURLFormatter URLFromString:urlString] : nil;
}

#pragma mark Graphics

- (NSString *)inlineGraphicClearValue;
{
    // Support left, right, or both; where both is the default
    
    NSString *result = [[self bundle] objectForInfoDictionaryKey:@"SVArticleGraphicsClearCSSValue"];
    
    if (![result isEqualToString:@"left"] && ![result isEqualToString:@"right"] && ![result isEqualToString:@"both"])
    {
        NSString *identifier = [[self bundle] bundleIdentifier];
        if ([identifier hasPrefix:@"com.blueballdesign.FirstClass"] ||
            [identifier hasPrefix:@"sandvox.SWD Franchise"])
        {
            result = @"right";
        }
        else if ([identifier hasPrefix:@"com.blueballdesign.Cubicle"] ||
                 [identifier hasPrefix:@"com.blueballdesign.Quantum "] ||
                 [identifier hasPrefix:@"com.sandvoxdesigner.Shadow "] ||
                 [identifier hasPrefix:@"com.sandvoxdesigner.Showcase "] ||
                 [identifier hasPrefix:@"com.sandvoxdesigner.Blueball Smooth "] ||
                 [identifier hasPrefix:@"com.blueballdesign.Snapshot_"] ||
                 [identifier hasPrefix:@"com.blueballdesign.Blueball_Synergy"] ||
                 [identifier hasPrefix:@"com.sandvoxdesigner.Trifecta "] ||
                 [identifier hasPrefix:@"com.blueballdesign.White_"] ||
                 [identifier hasPrefix:@"sandvox.SWD Big Time "] ||
                 [identifier hasPrefix:@"sandvox.SWD Bravado "] ||
                 [identifier hasPrefix:@"sandvox.SWD Crafty "] ||
                 [identifier hasPrefix:@"sandvox.SWD Discovery "] ||
                 [identifier hasPrefix:@"sandvox.SWD Inspiration"] ||
                 [identifier hasPrefix:@"sandvox.SWD Mojo"] ||
                 [identifier hasPrefix:@"sandvox.SWD Override "] ||
                 [identifier hasPrefix:@"sandvox.SWD Seclusion"] ||
                 [identifier hasPrefix:@"sandvox.SWD Suspicion"])
        {
            result = @"left";
        }
        else
        {
            result = @"both";
        }
    }
    
    return result;
}

#pragma mark Placeholder Image

/*!	Return path for placeholder image, if it exists
*/
- (NSURL *)placeholderImageURL;
{
	NSString *path = [[self bundle] pathForImageResource:@"placeholder"];		// just one placeholder per design
    if (path) return [NSURL fileURLWithPath:path];
    return nil;
}

+ (NSURL *)placeholderImageURLForDesign:(KTDesign *)design;
{
    NSURL *result = [design placeholderImageURL];
    if (!result)
    {
        result = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForImageResource:@"placeholder"]];
    }
    
    OBPOSTCONDITION(result);
    return result;
}

#pragma mark 

- (int)textWidth
{
	NSString *textWidthString = [self pluginPropertyForKey:@"textWidth"];
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
	return [self pluginPropertyForKey:@"imageReplacement"];
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
    
    NSString *path = [[self bundle] pathForResource:fileName ofType:@"qtz"];	// just one per design
    if (path)
    {
        return [NSURL fileURLWithPath:path];
    }
    
    return nil;
}

#pragma mark -

- (NSImage *)thumbnail
{
	if (nil == _thumbnail)
	{
		NSString *path = [self thumbnailPath];
		if (nil != path)
		{
			NSImage *unscaledThumb = [[[NSImage alloc] initByReferencingFile:path] autorelease];
			[unscaledThumb normalizeSize];
			_thumbnail = [[unscaledThumb imageWithMaxWidth:kDesignThumbWidth height:kDesignThumbHeight] retain];
			// make sure thumbnail is not too big!
		}
	}
	return _thumbnail;
}

- (CGImageRef)thumbnailCG
{
	if (nil == _thumbnailCG)
	{
		NSString *path = [self thumbnailPath];
		if (nil != path)
		{
			CGImageSourceRef source = CGImageSourceCreateWithURL((CFURLRef)[NSURL fileURLWithPath:path],nil);
			if (source)
			{
				_thumbnailCG = CGImageSourceCreateImageAtIndex(source, 0, nil);
				CFRelease(source);
			}
		}
	}
	return _thumbnailCG;
}



// Special version that compares the titles - but uses the ParentTitle if it exists
- (NSComparisonResult)compareTitles:(KTDesign *)aDesign;
{
	return [[self titleOrParentTitle] caseInsensitiveCompare:[aDesign titleOrParentTitle]];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ %@", [super description], [self identifier]];
}

#pragma mark design coalescing into families

- (HierMenuType)hierMenuType;
{
	HierMenuType result = HIER_MENU_NONE;
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"disableHierMenus"])
	{
		result = HIER_MENU_NONE;		// Overridden by preference: no hier menus allowed.
	}
	else
	{
		NSNumber *hierMenuTypeNumber = [self pluginPropertyForKey:@"hierMenuType" obsoleteKey:@"HierMenuType"];
		if (hierMenuTypeNumber)
		{
			result =  [hierMenuTypeNumber intValue];
		}
		else
		{
			result = HIER_MENU_NONE;		// default if not specified.
		}
	}
	return result;
}

- (BOOL)isFamilyPrototype;
{
	BOOL result = NO;
	
	NSNumber *value = [self pluginPropertyForKey:@"isFamilyPrototype" obsoleteKey:@"IsFamilyPrototype"];
	if (value)
	{
		result = [value boolValue];
	}
	return result;
}

- (NSString *)titleOrParentTitle
{
	NSString *result = [self parentTitle];
	if (!result)
	{
		result = [self title];
	}
	return result;
}

#pragma mark -
#pragma mark Publishing

/*!	Generate a path based on the identifier.  Remove white space, and append version string.
	so Foo Bar Baz will look like FooBarBaz.1
*/
+ (NSString *)remotePathForDesignWithIdentifier:(NSString *)identifier
{
    NSString *result = [identifier stringByRemovingWhiteSpace];
	result = [result stringByReplacingOccurrencesOfString:@"." withString:@"_"];		// some ISPs don't like "."
	return result;
}

/*  Convenience method to get the remote path of a design
 */
- (NSString *)remotePath
{
	NSString *result = [[self class] remotePathForDesignWithIdentifier:[self identifier]];
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
	BOOL result = [[self pluginPropertyForKey:@"hasLocalFonts"] boolValue];
	return result;
}

- (NSString *)bannerCSSSelector
{
	NSString *result = [self pluginPropertyForKey:@"bannerCSSSelector"];
	return result;
}

// No longer needed, I believe
//- (NSString *)bannerName
//{
//	NSDictionary *info = [[self bundle] infoDictionary];
//	NSString *result = [info valueForKey:@"bannerName"];
//	return result;
//}

- (NSSize)bannerSize
{
	int width = [[self pluginPropertyForKey:@"bannerWidth"] intValue];
	int height = [[self pluginPropertyForKey:@"bannerHeight"] intValue];
	if (!width) width = 800;
	if (!height) height = 200;
	return NSMakeSize(width, height);
}

- (NSString *)viewport;
{
    NSString *result = [self pluginPropertyForKey:@"viewport"];
    if (![result isKindOfClass:[NSString class]])
    {
        result = [NSString stringWithFormat:@"width=%u", [self viewportWidth]];
    }
    return result;
}

/*	The width of the design for the iPhone's benefit.
 *	If no value is found in the dictionary we assume 771 pixels.
 */
- (NSUInteger)viewportWidth
{
	NSUInteger result = 771;
	
	NSNumber *viewport = [self pluginPropertyForKey:@"viewport"];
	if ([viewport respondsToSelector:@selector(unsignedIntegerValue)])
    {
		NSUInteger probablyResult = [viewport unsignedIntegerValue];
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
	if (!_resourceFileURLs)
	{
		NSMutableSet *buffer = [[NSMutableSet alloc] init];
		NSArray *extraIgnoredFiles = [[[self bundle] infoDictionary] objectForKey:@"ignoredResources"];
		if (!extraIgnoredFiles)
		{
			// Obsolete key
			extraIgnoredFiles = [[[self bundle] infoDictionary] objectForKey:@"KTIgnoredResources"];
		}
		
		// Build up set of filenames to ignore, since they are from other variations
		NSMutableSet *variationNamesToIgnore = [NSMutableSet set];
		if (NSNotFound != _variationIndex)
		{
			NSArray *variations = [[[self bundle] infoDictionary] objectForKey:@"variations"];
			for (NSUInteger i = 0 ; i < [variations count] ; i++)
			{
				NSDictionary *variation = [variations objectAtIndex:i];
				NSString *file = [variation objectForKey:@"file"];
				if (i != _variationIndex)
				{
					// ignore var. folder name except for var we're using
					[variationNamesToIgnore addObject:file];
				}
				// Ignore all variation CSS files
				OBASSERT(![file isEqualToString:@""]);
                [variationNamesToIgnore addObject:[file stringByAppendingPathExtension:@"css"]];
				// Note: all thumbnails are ignored below.
			}
		}
		
		// Run through all files in the bundle
		NSString *designBundlePath = [[self bundle] bundlePath];
		NSEnumerator *resourcesEnumerator = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:designBundlePath error:NULL] objectEnumerator];
		NSString *aFilename;
		
		while (aFilename = [resourcesEnumerator nextObject])
		{
			// Ignore any special files
			if ([aFilename hasPrefix:@"."]) continue;
			if ([[aFilename pathExtension] isEqualToStringCaseInsensitive:@"psd"]) continue;
			if ([aFilename isEqualToStringCaseInsensitive:@"Info.plist"]) continue;
			if ([[aFilename stringByDeletingPathExtension] hasSuffix:@"thumbnail"]) continue;
			if ([aFilename isEqualToStringCaseInsensitive:@"sources"]) continue;
			if ([aFilename isEqualToStringCaseInsensitive:@"testing_files"]) continue;
			if ([variationNamesToIgnore containsObject:aFilename])	continue;
			if (extraIgnoredFiles && [extraIgnoredFiles containsObject:aFilename])	continue;
			if ([[aFilename stringByDeletingPathExtension] isEqualToString:@"placeholder"])	continue;
						
			// Locate the full path and add to the list if of a suitable type
            NSString *resourceFilePath = [designBundlePath stringByAppendingPathComponent:aFilename];
			NSURL *resourceFileURL = [NSURL fileURLWithPath:resourceFilePath];
			NSString *UTI = [KSWORKSPACE ks_typeOfFileAtURL:[NSURL fileURLWithPath:resourceFilePath]];
			if ([UTI conformsToUTI:(NSString *)kUTTypeImage] ||
				[UTI conformsToUTI:(NSString *)kUTTypePlainText] ||
				[UTI conformsToUTI:(NSString *)kUTTypeRTF] ||
                [UTI isEqualToUTI:(NSString *)kUTTypeFolder])
			{
				OBASSERT(resourceFileURL);
                [buffer addObject:resourceFileURL];
			}
			else
			{
				LOG((@"NOT uploading %@ since it is UTI:%@", aFilename, UTI));
			}
		}
		
		// Tidy up
		_resourceFileURLs = [buffer copy];
		[buffer release];
	}
	
	return _resourceFileURLs;
}

/*	Every design should have a main.css file; this builds up its data (including variation data)
 */
- (void)writeCSS:(SVHTMLContext *)context;
{
	if ([self bundle])
	{
		NSString *basePath = [[self bundle] resourcePath];
		NSString *fullPath = [basePath stringByAppendingPathComponent:@"main.css"];
		[context addResourceAtURL:[NSURL fileURLWithPath:fullPath] destination:SVDestinationMainCSS options:0];
		
		NSDictionary *variationDict = [self variationDict];
		id file = [variationDict objectForKey:@"file"];
		if (file)
		{
			NSString *fileCSS = [NSString stringWithFormat:@"%@.css", file];
			fullPath = [basePath stringByAppendingPathComponent:fileCSS];
			[context addResourceAtURL:[NSURL fileURLWithPath:fullPath] destination:SVDestinationMainCSS options:0];
		}
        
        
        // Blockquote compatibility
        NSString *identifier = [self identifier];
        if ([identifier hasPrefix:@"com.11Mystics.Sandvox.Aerolite."] ||
            [identifier isEqualToString:@"com.11Mystics.Sandvox.Daroo"])
        {
            [context addCSSString:@"blockquote { float:none; width:auto; }"];
        }
        
        
        // Graphic clearing
        NSString *clearRule = [NSString stringWithFormat:
                               @".callout-container, .graphic-container { clear:%@; }",
                               [self inlineGraphicClearValue]];
        
        [context addCSSString:clearRule];
	}
}

#pragma mark -
#pragma mark IKImageBrowserViewItem

- (NSString *)  imageUID;  /* required */
{
	NSString *result = [[self bundle] bundlePath];
	if (NSNotFound != _variationIndex)
	{
		result = [result stringByAppendingFormat:@".%d", _variationIndex];
	}
	return result;
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
	if (self.isContracted && [self.family.designs count] > 1 )
	{
		//return (id) [self.familyPrototype thumbnailCG];
		
		NSArray *familyDesigns = self.family.designs.allObjects;
		CGImageRef result = nil;
		NSNumber *indexNumber = [NSNumber numberWithInt:self.imageVersion];
		result = (CGImageRef) [self.thumbnails objectForKey:indexNumber];
		if (!result)		// see if we have a cached image....
		{
			int safeIndex = self.imageVersion;
			if ( (safeIndex != NSNotFound) && (safeIndex >= [familyDesigns count]) )
			{
				safeIndex = 0;	// make sure we don't overflow number of design variations.  Allow for NSNotFound
			}
			KTDesign *familyPrototype = [self familyPrototype];
			if (!familyPrototype) familyPrototype = self;	// use self, the first item in the list, as the prototype
			KTDesign *whichDesign = (safeIndex == NSNotFound) ? familyPrototype : [familyDesigns objectAtIndex:safeIndex];
			result = [whichDesign thumbnailCG];
			
			if (result)
			{
				[self.thumbnails setObject:(id)result forKey:indexNumber];
			}
		}
		if (!result)	// missing thumb?
		{
			static CGImageRef sMissingImage = nil;
			if (!sMissingImage)
			{
				NSURL *placeholderURL = [NSURL fileURLWithPath:
										 [[NSBundle mainBundle] pathForImageResource:@"LogoPlaceholder"]];
				if (nil != placeholderURL)
				{
					CGImageSourceRef source = CGImageSourceCreateWithURL((CFURLRef)placeholderURL,nil);
					if (source)
					{
						sMissingImage = CGImageSourceCreateImageAtIndex(source, 0, nil);
						CFRelease(source);
					}
				}
			}
			result = sMissingImage;
		}
		return (id) result;
	}
	else	// expanded, or there is not a family prototype -- just show your regular thumbnail.
	{
		return (id) [self thumbnailCG];
	}
}
/*! 
 @method imageTitle
 @abstract Returns the title to display as a NSString. Use setValue:forKey: with IKImageBrowserCellTitleAttribute to set text attributes.
 */
- (NSString *) imageTitle;
{
	NSString *result = (self.isContracted) ? self.titleOrParentTitle : self.title;
	return result;
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

#pragma mark -
#pragma mark Scrubbing

- (void) scrub:(float)howFar;
{
	int designCount = [self.family.designs count];
	int whichIndex = howFar * designCount;
	whichIndex = MIN(whichIndex, designCount-1);
	self.imageVersion = whichIndex;
}

@end

