//
//  KTDesign.h
//  Marvel
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
//

#import "KSPlugInWrapper.h"


enum { HIER_MENU_NONE, HIER_MENU_HORIZONTAL, HIER_MENU_VERTICAL };

@class KTImageScalingSettings;

@protocol IKImageBrowserItem <NSObject> @end    // weirdly ImageKit only declares it as an informal protocol

extern const int kDesignThumbWidth;
extern const int kDesignThumbHeight;


@interface KTDesign : KSPlugInWrapper <IKImageBrowserItem>
{
    @protected
    NSImage *myThumbnail;
	CGImageRef *myThumbnailCG;
	NSSet	*myResourceFileURLs;
	
	BOOL myFontsLoaded;
}

+ (NSArray *)consolidateDesignsIntoFamilies:(NSArray *)designs;
- (NSString *)parentBundleIdentifier;

- (int)numberOfSubDesigns;
- (NSArray *)subDesigns;

+ (NSString *)remotePathForDesignWithIdentifier:(NSString *)identifier;
- (NSString *)remotePath;

- (NSString *)contributor;		// externally visible author's name, shows up in design chooser
- (NSURL *)URL;
- (int)textWidth;
- (int)hierMenuType;
- (NSDictionary *)imageReplacementTags;	// returns a dictionary, key is the tag (h3, #sitemenu li, etc.), value is URL to pull apart with options for renderer.
- (NSString *)sidebarBorderable;
- (NSString *)calloutBorderable;
- (NSString *)genre;	
- (NSString *)color;	// dark, light, or color
- (BOOL)menusUseNonBreakingSpaces;
- (NSColor *)mainColor;		// from RGB string, to help with thumbnail variations

// Images
- (NSImage *)thumbnail;
- (CGImageRef)thumbnailCG;

- (NSString *)placeholderImagePath;

- (BOOL)allowsBannerSubstitution;
- (NSString *)bannerCSSSelector;
- (BOOL)hasLocalFonts;


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
- (NSString *)titleOrParentName;

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
