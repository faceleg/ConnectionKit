//
//  KTDesign.h
//  Marvel
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
//

#import "KSPlugInWrapper.h"


typedef enum { HIER_MENU_NONE, HIER_MENU_HORIZONTAL, HIER_MENU_VERTICAL } HierMenuType;
// Horizontal: Usual horizontal layout, submenus spew down vertically
// Vertical: Vertical layout of menus (e.g. in sidebar), submenus spew out vertically to the right

@class KTImageScalingSettings, KTDesignFamily;

@protocol IKImageBrowserItem <NSObject> @end    // weirdly ImageKit only declares it as an informal protocol

extern const int kDesignThumbWidth;
extern const int kDesignThumbHeight;


@interface KTDesign : KSPlugInWrapper <IKImageBrowserItem>
{
    @protected
    NSImage *_thumbnail;
	CGImageRef  _thumbnailCG;  // CGImageRefs aren't supposed to be pointers
	NSSet	*_resourceFileURLs;
	KTDesign *_familyPrototype;
	KTDesignFamily *_family;
	NSMutableDictionary *_thumbnails;	// keyed by nsnumber for version so it can be arbitrary sized
	
	BOOL _fontsLoaded;
	BOOL _contracted;
	NSUInteger _imageVersion;
	NSUInteger _variationIndex;
}

@property (copy) NSImage *thumbnail;
@property  CGImageRef thumbnailCG;
@property (nonatomic, copy) NSSet *resourceFileURLs;
@property (retain) KTDesign *familyPrototype;
@property (retain) KTDesignFamily *family;
@property (retain) NSMutableDictionary *thumbnails;
@property  BOOL fontsLoaded;
@property  (assign, getter=isContracted) BOOL contracted;
@property  NSUInteger imageVersion;
@property  NSUInteger variationIndex;

- (id)initWithBundle:(NSBundle *)bundle;
- (id)initWithBundle:(NSBundle *)bundle variation:(NSUInteger)variationIndex;

+ (NSArray *)reorganizeDesigns:(NSArray *)designs familyRanges:(NSArray **)outRanges;
- (NSString *)parentBundleIdentifier;

+ (NSArray *)genreValues;
+ (NSArray *)colorValues;
+ (NSArray *)widthValues;

+ (NSString *)remotePathForDesignWithIdentifier:(NSString *)identifier;
- (NSString *)remotePath;

- (NSString *)contributor;		// externally visible author's name, shows up in design chooser
- (NSURL *)URL;
- (int)textWidth;
- (HierMenuType)hierMenuType;
- (NSDictionary *)imageReplacementTags;	// returns a dictionary, key is the tag (h3, #sitemenu li, etc.), value is URL to pull apart with options for renderer.
- (NSString *)sidebarBorderable;
- (NSString *)calloutBorderable;
- (NSString *)genre;	
- (NSString *)color;	// dark, light, or colorful
- (NSString *)width;	// standard, wide, or flexible
- (BOOL)menusUseNonBreakingSpaces;

// Images
- (NSImage *)thumbnail;
- (CGImageRef)thumbnailCG;

- (NSURL *)placeholderImageURL;

- (BOOL)allowsBannerSubstitution;
- (NSString *)bannerCSSSelector;
- (BOOL)hasLocalFonts;
- (BOOL)isFamilyPrototype;
- (void) scrub:(float)howFar;


#pragma mark Image Replacement

- (NSImage *)replacementImageForCode:(NSString *)aCode
                              string:(NSString *)aString
                                size:(NSNumber *)aSize;

- (NSURL *)URLForCompositionForImageReplacementCode:(NSString *)code;

   
// Viewport
- (unsigned)viewport;	// Mainly used by the iPhone to know a page's optimum width

// Other
- (NSComparisonResult)compareTitles:(KTDesign *)aDesign;
- (void) loadLocalFontsIfNeeded;
- (NSString *)titleOrParentTitle;

// Resource data
- (NSSet *)resourceFileURLs;
- (NSData *)dataForResourceAtPath:(NSString *)path MIMEType:(NSString **)mimeType error:(NSError **)error;
- (NSData *)mainCSSData;

@end

@interface KTDesign (ScaledImages)

// Media uses. e.g. KTSidebarPageMedia which covers photo pages which have a sidebar
+ (NSDictionary *)infoForMediaUse:(NSString *)anImageName;

- (NSDictionary *)imageScalingPropertiesForUse:(NSString *)mediaUse;
- (KTImageScalingSettings *)imageScalingSettingsForUse:(NSString *)mediaUse;

@end

/*
 Designs will be bundles without code, but will have an info dictionary
 that provides:
 uniqueDesignID
 variants
 variant1ID
 variant2ID
 variant3ID
 pageDesigns
 indexPageDesigns
 pageletDesigns?

 Info.plist
 Default Variant (Variant 1)
 css file for variant
 graphics for variant
 html template file for each supported page type
 photo album
 weblog
 index
 Variant
 Variant
 */
