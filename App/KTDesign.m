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


const CGFloat kMyDrawingFunctionWidth = 100.0;
const CGFloat kMyDrawingFunctionHeight = 65.0;

void MyDrawingFunction(CGContextRef context, CGRect bounds)
{
	CGRect imageBounds = CGRectMake(0.0, 0.0, kMyDrawingFunctionWidth, kMyDrawingFunctionHeight);
	CFMutableArrayRef contexts = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
	size_t bytesPerRow;
	void *bitmapData;
	CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
	CGImageRef contextImage;
	CGRect effectBounds;
	unsigned char *pixels;
	CGFloat minX, maxX, minY, maxY;
	size_t width, height;
	CGRect drawRect;
	CGMutablePathRef path;
	CGGradientRef gradient;
	CGFloat topHeight;
	CGFloat bottomHeight;
	CGColorRef clearColor;
	CGContextRef maskContext;
	CGImageRef maskImage;
	CGFloat resolution;
	CGColorRef color;
	CFMutableArrayRef colors;
	CGAffineTransform transform;
	
	transform = CGContextGetUserSpaceToDeviceSpaceTransform(context);
	resolution = sqrt(fabs(transform.a * transform.d - transform.b * transform.c)) * 0.5 * (bounds.size.width / imageBounds.size.width + bounds.size.height / imageBounds.size.height);
	
	CGContextSaveGState(context);
	CGContextClipToRect(context, bounds);
	CGContextTranslateCTM(context, bounds.origin.x, bounds.origin.y);
	CGContextScaleCTM(context, (bounds.size.width / imageBounds.size.width), (bounds.size.height / imageBounds.size.height));
	
	// Setup for Glass Effect
	CFArrayAppendValue(contexts, context);
	bytesPerRow = 4 * round(bounds.size.width);
	bitmapData = calloc(bytesPerRow * round(bounds.size.height), 8);
	context = CGBitmapContextCreate(bitmapData, round(bounds.size.width), round(bounds.size.height), 8, bytesPerRow, space, kCGImageAlphaPremultipliedLast);
	CGContextClipToRect(context, bounds);
	CGContextScaleCTM(context, (bounds.size.width / imageBounds.size.width), (bounds.size.height / imageBounds.size.height));
	
	// Layer 1
	
	// Glass Effect
	bitmapData = CGBitmapContextGetData(context);
	pixels = (unsigned char *)bitmapData;
	width = round(bounds.size.width);
	height = round(bounds.size.height);
	minX = width;
	maxX = -1.0;
	minY = height;
	maxY = -1.0;
	for (size_t row = 0; row < height; row++) {
		for (size_t column = 0; column < width; column++) {
			if (pixels[4 * (width * row + column) + 3] > 0) {
				minX = fmin(minX, (CGFloat)column);
				maxX = fmax(maxX, (CGFloat)column);
				minY = fmin(minY, (CGFloat)(height - row));
				maxY = fmax(maxY, (CGFloat)(height - row));
			}
		}
	}
	contextImage = CGBitmapContextCreateImage(context);
	CGContextRelease(context);
	free(bitmapData);
	context = (CGContextRef)CFArrayGetValueAtIndex(contexts, CFArrayGetCount(contexts) - 1);
	CFArrayRemoveValueAtIndex(contexts, CFArrayGetCount(contexts) - 1);
	CGContextDrawImage(context, imageBounds, contextImage);
	if ((minX <= maxX) && (minY <= maxY)) {
		CGContextSaveGState(context);
		effectBounds = CGRectMake(minX, minY - 1.0, maxX - minX + 1.0, maxY - minY + 1.0);
		bytesPerRow = round(effectBounds.size.width);
		maskContext = CGBitmapContextCreate(NULL, round(effectBounds.size.width), round(effectBounds.size.height), 8, bytesPerRow, NULL, kCGImageAlphaOnly);
		CGContextDrawImage(maskContext, CGRectMake(-effectBounds.origin.x, -effectBounds.origin.y, bounds.size.width, bounds.size.height), contextImage);
		maskImage = CGBitmapContextCreateImage(maskContext);
		CGContextClipToRect(context, bounds);
		CGContextScaleCTM(context, (imageBounds.size.width / bounds.size.width), (imageBounds.size.height / bounds.size.height));
		CGContextClipToMask(context, effectBounds, maskImage);
		CGImageRelease(maskImage);
		CGContextRelease(maskContext);
		path = CGPathCreateMutable();
		topHeight = effectBounds.size.height - (effectBounds.size.height * 0.7) * sqrt(1.0 - (0.5 * 0.5));
		bottomHeight = effectBounds.size.height * 0.7;
		drawRect = effectBounds;
		drawRect.origin.y -= drawRect.size.height * 0.7;
		drawRect.size.height *= 2.0 * 0.7;
		drawRect.size.width *= 1.0 / 0.5;
		drawRect.origin.x -= 0.5 * (drawRect.size.width - effectBounds.size.width);
		CGPathAddEllipseInRect(path, NULL, drawRect);
		CGContextSaveGState(context);
		CGContextAddPath(context, path);
		CGContextEOClip(context);
		drawRect = effectBounds;
		drawRect.size.height = bottomHeight;
		color = CGColorCreateGenericRGB(0.0, 0.0, 0.0, 0.5);
		clearColor = CGColorCreateCopyWithAlpha(color, 0.0);
		colors = CFArrayCreateMutable(NULL, 2, &kCFTypeArrayCallBacks);
		CFArrayAppendValue(colors, clearColor);
		CFArrayAppendValue(colors, color);
		gradient = CGGradientCreateWithColors(CGColorGetColorSpace(color), colors, NULL);
		CFRelease(colors);
		CGColorRelease(clearColor);
		CGColorRelease(color);
		CGContextDrawLinearGradient(context, gradient, CGPointMake(drawRect.origin.x, CGRectGetMaxY(drawRect)), drawRect.origin, 0);
		CGContextRestoreGState(context);
		CGContextAddPath(context, path);
		CGContextAddRect(context, effectBounds);
		CGContextEOClip(context);
		CGPathRelease(path);
		drawRect = effectBounds;
		drawRect.size.height = topHeight;
		drawRect.origin.y += effectBounds.size.height - topHeight;
		CGContextDrawLinearGradient(context, gradient, CGPointMake(drawRect.origin.x, CGRectGetMaxY(drawRect)), drawRect.origin, 0);
		CGGradientRelease(gradient);
		color = CGColorCreateGenericRGB(1.0, 1.0, 1.0, 0.3);
		CGContextSetFillColorWithColor(context, color);
		CGColorRelease(color);
		CGContextFillRect(context, effectBounds);
		CGContextRestoreGState(context);
	}
	CGImageRelease(contextImage);
	
	CGContextRestoreGState(context);
	CGColorSpaceRelease(space);
	CFRelease(contexts);
}


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
				[result addObject:result];	// first time seen, so add to result list
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
			myThumbnail = [[unscaledThumb imageWithMaxWidth:100 height:65] retain];
			// make sure thumbnail is not too big!
		}
	}
	return myThumbnail;
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
	return IKImageBrowserNSImageRepresentationType;
}
/*! 
 @method imageRepresentation
 @abstract Returns the image to display (required). Can return nil if the item has no image to display.
 @discussion This methods is called frequently, so the receiver should cache the returned instance.
 */
- (id) imageRepresentation; /* required */
{
	return self.thumbnail;
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

