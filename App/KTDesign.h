//
//  KTDesign.h
//  Marvel
//
//  Copyright (c) 2004-2005 Biophony, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KTAppPlugin.h"


@class KTImageScalingSettings;


@interface KTDesign : KTAppPlugin
{
    @protected
    NSImage *myThumbnail;
	NSSet	*myResourceFiles;
}

- (int)numberOfSubDesigns;
- (NSArray *)subDesigns;

- (NSString *)remotePath;
- (NSString *)contributor;		// externally visible author's name, shows up in design chooser
- (NSURL *)URL;
- (int)textWidth;
- (NSDictionary *)imageReplacementTags;	// returns a dictionary, key is the tag (h3, #sitemenu li, etc.), value is URL to pull apart with options for renderer.
- (NSString *)sidebarBorderable;
- (NSString *)calloutBorderable;
- (BOOL)menusUseNonBreakingSpaces;

// Images
- (NSImage *)thumbnail;

- (NSImage *)replacementImageForCode:(NSString *)aCode string:(NSString *)aString size:(NSNumber *)aSize;

- (NSString *)placeholderImagePath;

- (BOOL)allowsBannerSubstitution;
- (NSString *)bannerName;
- (NSSize)bannerSize;

- (KTImageScalingSettings *)imageScalingSettingsForUse:(NSString *)mediaUse;
- (NSSize)maximumMediaSizeForUse:(NSString *)mediaUse;	// e.g. how big a Photo page should be

// Viewport
- (unsigned)viewport;	// Mainly used by the iPhone to know a page's optimum width

// Other
- (NSComparisonResult)compareTitles:(KTDesign *)aDesign;

// Resource data
- (NSSet *)resourceFiles;
- (NSData *)dataForResourceAtPath:(NSString *)path MIMEType:(NSString **)mimeType error:(NSError **)error;
- (NSData *)mainCSSData;

@end

@interface KTDesign ( ScaledImages )
// Media uses. e.g. KTSidebarPageMedia which covers photo pages which have a sidebar
+ (NSDictionary *)defaultMediaUses;
+ (NSDictionary *)infoForMediaUse:(NSString *)anImageName;
+ (void)setInfo:(NSDictionary *)aTypeInfoDictionary forMediaUse:(NSString *)anImageName;
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
